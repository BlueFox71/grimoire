import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'merge.dart';
import 'model.dart';

/// Contenu du QR code affiché par le PC.
class QrPayload {
  final int v;
  final List<String> hosts;
  final int port;
  final String key;

  QrPayload({this.v = 1, required this.hosts, required this.port, required this.key});

  String encode() => jsonEncode({'v': v, 'app': 'grimoire', 'hosts': hosts, 'port': port, 'key': key});

  static QrPayload? decode(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map || j['app'] != 'grimoire') return null;
      return QrPayload(
        v: (j['v'] as num).toInt(),
        hosts: [for (final h in j['hosts'] as List) h as String],
        port: (j['port'] as num).toInt(),
        key: j['key'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

class SyncException implements Exception {
  final String message;
  SyncException(this.message);
  @override
  String toString() => message;
}

String _randomKey() {
  final r = Random.secure();
  return base64Url.encode(List<int>.generate(32, (_) => r.nextInt(256))).replaceAll('=', '');
}

bool _isPrivate(InternetAddress a) {
  final b = a.rawAddress;
  return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168);
}

/// Serveur de synchro ouvert sur le PC pendant [timeout], pour une seule synchro.
class SyncServer {
  final HttpServer _http;
  final QrPayload payload;
  final Completer<MergeResult?> _done = Completer();
  Timer? _timer;
  bool _used = false;

  SyncServer._(this._http, this.payload);

  Future<MergeResult?> get done => _done.future;

  static Future<SyncServer> start({
    required Library Function() current,
    required Future<void> Function(MergeResult) onMerged,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final http = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final hosts = <String>[];
    try {
      for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in ni.addresses) {
          if (_isPrivate(a)) hosts.add(a.address);
        }
      }
    } catch (_) {}
    final server = SyncServer._(http, QrPayload(hosts: hosts, port: http.port, key: _randomKey()));
    server._timer = Timer(timeout, server.stop);
    http.listen((req) => server._handle(req, current, onMerged));
    return server;
  }

  Future<void> _handle(HttpRequest req, Library Function() current, Future<void> Function(MergeResult) onMerged) async {
    final res = req.response;
    try {
      if (req.method != 'POST' || req.uri.path != '/sync') {
        res.statusCode = HttpStatus.notFound;
        return;
      }
      if (req.headers.value('X-Grimoire-Key') != payload.key) {
        res.statusCode = HttpStatus.forbidden;
        return;
      }
      if (_used) {
        res.statusCode = HttpStatus.gone;
        return;
      }
      _used = true;
      final body = jsonDecode(await utf8.decodeStream(req)) as Map<String, dynamic>;
      final phone = Library.fromJson(body['library'] as Map<String, dynamic>);
      final result = mergeLibraries(current(), phone);
      await onMerged(result);
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({'library': result.merged.toJson(), 'received': result.changedOnA, 'sent': result.changedOnB}));
      if (!_done.isCompleted) _done.complete(result);
    } catch (_) {
      res.statusCode = HttpStatus.badRequest;
    } finally {
      await res.close();
      if (_done.isCompleted) unawaited(stop());
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    if (!_done.isCompleted) _done.complete(null);
    await _http.close(force: true);
  }
}

class SyncOutcome {
  final Library merged;
  final int received;
  final int sent;
  SyncOutcome(this.merged, this.received, this.sent);
}

/// Côté téléphone : envoie la bibliothèque au PC du QR code et reçoit la fusion.
/// `received` = livres modifiés sur le téléphone, `sent` = livres modifiés sur le PC.
Future<SyncOutcome> syncWithPc(QrPayload p, Library local, String deviceName, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    for (final host in p.hosts) {
      // Délai court pour trouver le PC, puis délai large pour l'échange lui-même
      // (~900 livres dans chaque sens, fusion et sauvegarde sur le PC).
      try {
        final probe = await Socket.connect(host, p.port, timeout: const Duration(seconds: 3));
        probe.destroy();
      } catch (_) {
        continue;
      }
      http.Response res;
      try {
        res = await c
            .post(
              Uri.parse('http://$host:${p.port}/sync'),
              headers: {'X-Grimoire-Key': p.key, 'Content-Type': 'application/json'},
              body: jsonEncode({'deviceName': deviceName, 'library': local.toJson()}),
            )
            .timeout(const Duration(seconds: 120));
      } catch (_) {
        throw SyncException('Le PC ne répond plus. Relance la synchro sur le PC et réessaie.');
      }
      if (res.statusCode == HttpStatus.gone || res.statusCode == HttpStatus.forbidden) {
        throw SyncException('QR code expiré, relance la synchro sur le PC.');
      }
      if (res.statusCode != HttpStatus.ok) {
        throw SyncException('La synchro a échoué (erreur ${res.statusCode}).');
      }
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final merged = Library.fromJson(j['library'] as Map<String, dynamic>);
      // Du point de vue du téléphone : reçus = changés ici (sent côté PC).
      return SyncOutcome(merged, (j['sent'] as num).toInt(), (j['received'] as num).toInt());
    }
    throw SyncException('PC introuvable sur le Wi-Fi. Vérifie que le téléphone et le PC sont sur le même réseau.');
  } finally {
    if (client == null) c.close();
  }
}
