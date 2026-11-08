import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/tags.dart';

import 'test_helpers.dart';

void main() {
  test('isKept applies the vote rule', () {
    expect(isKept(theme('Young Adult', 27, 16)), isFalse);
    expect(isKept(theme('Dragons', 171, 1)), isTrue);
    expect(isKept(theme('X', 3, 0)), isTrue);
    expect(isKept(theme('X', 6, 3)), isTrue);
    // Livres peu lus : un thème que personne ne conteste est gardé, même avec 0 à 2 votes.
    expect(isKept(theme('Romance M/M', 1, 0)), isTrue);
    expect(isKept(theme('Romance', 0, 0)), isTrue);
    // Contesté : il faut au moins 3 votes pour et deux fois plus de pour que de contre.
    expect(isKept(theme('X', 2, 1)), isFalse);
    expect(isKept(theme('X', 5, 3)), isFalse);
  });

  test('displayTags respects manual edits', () {
    final b = book('a', tags: [theme('Dragons', 171, 1), theme('Young Adult', 27, 16)])
      ..manualRemoved = {'Dragons'}
      ..manualAdded = {'trope:Fae'};
    expect(displayTags(b).map((t) => t.name), ['Fae']);
  });

  test('displayTags puts themes before tropes, by votes', () {
    final b = book('a', tags: [trope('Found family', 20), theme('Magie', 95), theme('Dragons', 171)]);
    expect(displayTags(b).map((t) => t.name), ['Dragons', 'Magie', 'Found family']);
  });

  test('needsCompletion under 3 displayed tags', () {
    expect(needsCompletion(book('a', tags: [theme('A'), theme('B')])), isTrue);
    expect(needsCompletion(book('a', tags: [theme('A'), theme('B'), trope('C')])), isFalse);
  });

  test('normalize ignores case, accents and extra spaces', () {
    expect(normalize('  Le Prince  Cruel '), normalize('le prince cruel'));
    expect(normalize('Élan'), 'elan');
    expect(normalize('Ça çà Œuvre'), 'ca ca oeuvre');
  });
}
