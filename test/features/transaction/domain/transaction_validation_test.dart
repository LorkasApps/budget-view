import 'package:flutter_test/flutter_test.dart';

import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_validation.dart';

void main() {
  group('description', () {
    test('rejects empty', () {
      expect(TransactionValidation.description(''), isNotNull);
      expect(TransactionValidation.description('  '), isNotNull);
    });
    test('accepts text', () {
      expect(TransactionValidation.description('REWE'), isNull);
    });
  });

  group('amount (magnitude field)', () {
    test('rejects empty, non-numeric, zero and signed input', () {
      expect(TransactionValidation.amount(''), isNotNull);
      expect(TransactionValidation.amount('abc'), isNotNull);
      expect(TransactionValidation.amount('0'), isNotNull);
      expect(TransactionValidation.amount('0,00'), isNotNull);
      expect(TransactionValidation.amount('-5'), isNotNull);
    });
    test('accepts positive comma and dot notation', () {
      expect(TransactionValidation.amount('47,32'), isNull);
      expect(TransactionValidation.amount('47.32'), isNull);
      expect(TransactionValidation.amount('1'), isNull);
    });
  });

  group('bookingDate', () {
    final now = DateTime(2026, 8, 10);
    test('rejects null and future', () {
      expect(TransactionValidation.bookingDate(null, now: now), isNotNull);
      expect(
        TransactionValidation.bookingDate(DateTime(2026, 8, 11), now: now),
        isNotNull,
      );
    });
    test('accepts today and past', () {
      expect(TransactionValidation.bookingDate(now, now: now), isNull);
      expect(
        TransactionValidation.bookingDate(DateTime(2025, 1, 1), now: now),
        isNull,
      );
    });
  });

  group('category', () {
    test('rejects null / empty for a regular booking', () {
      expect(TransactionValidation.category(null), isNotNull);
      expect(TransactionValidation.category(''), isNotNull);
    });
    test('a transfer needs no category, null or empty', () {
      expect(
        TransactionValidation.category(null, kind: TransactionKind.transfer),
        isNull,
      );
      expect(
        TransactionValidation.category('', kind: TransactionKind.transfer),
        isNull,
      );
    });
    test('a transfer with a category set still passes', () {
      expect(
        TransactionValidation.category(
          'cat-1',
          kind: TransactionKind.transfer,
        ),
        isNull,
      );
    });
  });

  group('account', () {
    test('rejects null / empty', () {
      expect(TransactionValidation.account(null), isNotNull);
      expect(TransactionValidation.account(''), isNotNull);
    });
    test('accepts a uuid', () {
      expect(TransactionValidation.account('acc-1'), isNull);
    });
  });
}
