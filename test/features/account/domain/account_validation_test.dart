import 'package:flutter_test/flutter_test.dart';

import 'package:budget_view/features/account/domain/account_validation.dart';

void main() {
  group('name', () {
    test('rejects empty / whitespace', () {
      expect(AccountValidation.name(''), isNotNull);
      expect(AccountValidation.name('   '), isNotNull);
      expect(AccountValidation.name(null), isNotNull);
    });
    test('accepts non-empty', () {
      expect(AccountValidation.name('Giro'), isNull);
    });
  });

  group('openingBalance', () {
    test('rejects empty and non-numeric', () {
      expect(AccountValidation.openingBalance(''), isNotNull);
      expect(AccountValidation.openingBalance('abc'), isNotNull);
    });
    test('accepts comma, dot, negative', () {
      expect(AccountValidation.openingBalance('12,34'), isNull);
      expect(AccountValidation.openingBalance('12.34'), isNull);
      expect(AccountValidation.openingBalance('-50'), isNull);
    });
  });

  group('openingDate', () {
    final now = DateTime(2026, 8, 10);
    test('rejects null and future', () {
      expect(AccountValidation.openingDate(null, now: now), isNotNull);
      expect(
        AccountValidation.openingDate(DateTime(2026, 8, 11), now: now),
        isNotNull,
      );
    });
    test('accepts today and past', () {
      expect(AccountValidation.openingDate(now, now: now), isNull);
      expect(
        AccountValidation.openingDate(DateTime(2020, 1, 1), now: now),
        isNull,
      );
    });
  });
}
