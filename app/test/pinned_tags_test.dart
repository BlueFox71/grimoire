import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/ui/pinned_tags.dart';
import 'package:grimoire/ui/tag_picker.dart';
import 'package:grimoire/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('pins are limited to 5 and persisted', () async {
    final p = PinnedTags();
    await p.load();
    for (final t in ['A', 'B', 'C', 'D', 'E']) {
      expect(await p.toggle(t), isTrue);
    }
    expect(await p.toggle('F'), isFalse, reason: '6e épingle refusée');
    expect(p.pinned, ['A', 'B', 'C', 'D', 'E']);
    expect(await p.toggle('B'), isTrue, reason: 'retirer une épingle est toujours possible');
    final again = PinnedTags();
    await again.load();
    expect(again.pinned, ['A', 'C', 'D', 'E']);
  });

  testWidgets('tag picker star pins a theme, the 6th shows a message', (tester) async {
    final p = PinnedTags();
    await tester.runAsync(p.load);
    final counts = [for (final n in ['A', 'B', 'C', 'D', 'E', 'F']) MapEntry(n, 3)];
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: p,
      child: MaterialApp(theme: grimoireDark(), home: TagPicker(counts: counts, selected: const {})),
    ));
    for (final n in ['A', 'B', 'C', 'D', 'E']) {
      await tester.tap(find.byKey(Key('pin-$n')));
      await tester.pump();
    }
    expect(p.pinned, ['A', 'B', 'C', 'D', 'E']);
    await tester.tap(find.byKey(const Key('pin-F')));
    await tester.pump();
    expect(p.pinned.contains('F'), isFalse);
    expect(find.text('5 thèmes épinglés au maximum : retire d\'abord une étoile.'), findsOneWidget);
  });
}
