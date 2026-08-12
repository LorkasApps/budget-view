import 'package:budget_view/core/text/normalize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lower-cases, trims and collapses whitespace', () {
    expect(normalizeForMatching('  REWE   Markt  GmbH '), 'rewe markt gmbh');
  });

  test('collapses tabs and newlines too', () {
    expect(normalizeForMatching('REWE\tMarkt\nGmbH'), 'rewe markt gmbh');
  });

  test('leaves an already normalised value untouched', () {
    expect(normalizeForMatching('rewe markt gmbh'), 'rewe markt gmbh');
  });

  test('an empty or blank value normalises to empty', () {
    expect(normalizeForMatching(''), '');
    expect(normalizeForMatching('   '), '');
  });
}
