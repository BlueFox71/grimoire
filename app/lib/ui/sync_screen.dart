import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/library_controller.dart';
import '../core/sync.dart';
import 'theme.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Synchronisation')),
        body: Platform.isWindows ? const _PcSync() : const _PhoneSync(),
      );
}

String _summary(int received, int sent) => '↓ $received reçus · ↑ $sent envoyés';

/// PC : affiche le QR code pendant 2 minutes et attend le téléphone.
class _PcSync extends StatefulWidget {
  const _PcSync();

  @override
  State<_PcSync> createState() => _PcSyncState();
}

class _PcSyncState extends State<_PcSync> {
  SyncServer? _server;
  Timer? _tick;
  int _left = 120;
  String? _message;

  Future<void> _start() async {
    final controller = context.read<LibraryController>();
    await controller.flush();
    final server = await SyncServer.start(
      current: () => controller.library,
      onMerged: (r) async {
        await controller.store.backup('avant-synchro');
        await controller.replace(r.merged);
      },
    );
    setState(() {
      _server = server;
      _left = 120;
      _message = null;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _left = (_left - 1).clamp(0, 120));
    });
    final result = await server.done;
    _tick?.cancel();
    if (!mounted) return;
    setState(() {
      _server = null;
      _message = result == null
          ? 'Temps écoulé. Relance la synchro quand le téléphone est prêt.'
          : 'Synchro terminée : ${_summary(result.changedOnA, result.changedOnB)}';
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final server = _server;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (server == null) ...[
              Text(
                'Ouvre Grimoire sur ton téléphone, touche la synchro, puis scanne le QR code qui va s\'afficher.',
                textAlign: TextAlign.center,
                style: TextStyle(color: gc.muted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _start, icon: const Icon(Icons.qr_code_2), label: const Text('Synchroniser le téléphone')),
              if (_message != null) ...[const SizedBox(height: 16), Text(_message!, textAlign: TextAlign.center)],
            ] else ...[
              if (server.payload.hosts.isEmpty)
                const Text('Aucun réseau Wi-Fi local trouvé sur ce PC.')
              else
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(data: server.payload.encode(), size: 260),
                ),
              const SizedBox(height: 12),
              Text('Scanne ce code avec le téléphone · ${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}'),
              const SizedBox(height: 8),
              TextButton(onPressed: () => server.stop(), child: const Text('Annuler')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Téléphone : scanne le QR code du PC puis synchronise.
class _PhoneSync extends StatefulWidget {
  const _PhoneSync();

  @override
  State<_PhoneSync> createState() => _PhoneSyncState();
}

class _PhoneSyncState extends State<_PhoneSync> {
  bool _busy = false;
  bool _scanning = false;
  String? _message;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    final payload = raw == null ? null : QrPayload.decode(raw);
    if (payload == null) return;
    final controller = context.read<LibraryController>();
    setState(() {
      _busy = true;
      _scanning = false;
    });
    try {
      await controller.flush();
      final out = await syncWithPc(payload, controller.library.copy(), Platform.localHostname);
      await controller.replace(out.merged);
      if (mounted) setState(() => _message = 'Synchro terminée : ${_summary(out.received, out.sent)}');
    } on SyncException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    if (_scanning) {
      return Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: FilledButton(onPressed: () => setState(() => _scanning = false), child: const Text('Annuler')),
          ),
        ],
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sur le PC : Grimoire → synchro → « Synchroniser le téléphone ». Puis scanne le QR code (même Wi-Fi).',
              textAlign: TextAlign.center,
              style: TextStyle(color: gc.muted),
            ),
            const SizedBox(height: 16),
            if (_busy)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: () => setState(() {
                  _scanning = true;
                  _message = null;
                }),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scanner le QR code'),
              ),
            if (_message != null) ...[const SizedBox(height: 16), Text(_message!, textAlign: TextAlign.center)],
          ],
        ),
      ),
    );
  }
}
