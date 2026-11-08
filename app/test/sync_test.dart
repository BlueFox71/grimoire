import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/merge.dart';
import 'package:grimoire/core/model.dart';
import 'package:grimoire/core/sync.dart';
import 'package:http/http.dart' as http;

import 'test_helpers.dart';

QrPayload local(SyncServer s) => QrPayload(hosts: ['127.0.0.1'], port: s.payload.port, key: s.payload.key);

void main() {
  test('qr payload round-trip', () {
    final p = QrPayload(hosts: ['192.168.1.20', '10.0.0.5'], port: 51234, key: 'abc_DEF-123');
    final d = QrPayload.decode(p.encode())!;
    expect(d.hosts, ['192.168.1.20', '10.0.0.5']);
    expect(d.port, 51234);
    expect(d.key, 'abc_DEF-123');
    expect(jsonDecode(p.encode())['app'], 'grimoire');
  });

  test('decode rejects foreign QR', () {
    expect(QrPayload.decode('{"v":1}'), isNull);
    expect(QrPayload.decode('https://example.com'), isNull);
  });

  test('phone and pc libraries are merged both ways', () async {
    final pc = Library()..books['a'] = book('a');
    final phone = Library()..books['b'] = book('b');
    MergeResult? onPc;
    final server = await SyncServer.start(current: () => pc, onMerged: (r) async => onPc = r);
    expect(server.payload.key.length, greaterThanOrEqualTo(43));
    final out = await syncWithPc(local(server), phone, 'Téléphone de test');
    expect(out.merged.books.keys.toSet(), {'a', 'b'});
    expect(out.received, 1);
    expect(out.sent, 1);
    expect(onPc!.merged.books.keys.toSet(), {'a', 'b'});
    expect((await server.done)!.merged.books.length, 2);
    await server.stop();
  });

  test('wrong key is refused with 403', () async {
    final server = await SyncServer.start(current: () => Library(), onMerged: (_) async {});
    final res = await http.post(
      Uri.parse('http://127.0.0.1:${server.payload.port}/sync'),
      headers: {'X-Grimoire-Key': 'mauvaise'},
      body: jsonEncode({'deviceName': 'x', 'library': Library().toJson()}),
    );
    expect(res.statusCode, 403);
    await server.stop();
  });

  test('second sync with same key is refused', () async {
    final server = await SyncServer.start(current: () => Library(), onMerged: (_) async {});
    await syncWithPc(local(server), Library(), 'tel');
    await expectLater(syncWithPc(local(server), Library(), 'tel'), throwsA(isA<SyncException>()));
    await server.stop();
  });

  test('done resolves null after timeout', () async {
    final server = await SyncServer.start(
      current: () => Library(),
      onMerged: (_) async {},
      timeout: const Duration(milliseconds: 200),
    );
    expect(await server.done, isNull);
  });

  test('unreachable pc gives a french error', () async {
    final p = QrPayload(hosts: ['127.0.0.1'], port: 1, key: 'k');
    await expectLater(
      syncWithPc(p, Library(), 'tel'),
      throwsA(isA<SyncException>().having((e) => e.message, 'message', contains('PC introuvable'))),
    );
  });

  test('a slow pc merge (over 3 s) still completes', () async {
    final server = await SyncServer.start(
      current: () => Library()..books['a'] = book('a'),
      onMerged: (_) => Future.delayed(const Duration(seconds: 4)),
    );
    final out = await syncWithPc(local(server), Library(), 'tel');
    expect(out.merged.books.keys, ['a']);
    await server.stop();
  });
}
