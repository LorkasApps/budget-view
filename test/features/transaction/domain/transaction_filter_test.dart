import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx({
  String description = 'Kauf',
  String counterparty = '',
  String merchant = '',
  String note = '',
  int amountCents = -1000,
  String? categoryUuid,
  TransactionKind kind = TransactionKind.regular,
}) {
  return Transaction()
    ..accountUuid = 'account-1'
    ..bookingDate = DateTime(2026, 8, 3)
    ..description = description
    ..counterparty = counterparty
    ..merchant = merchant
    ..note = note
    ..amountCents = amountCents
    ..categoryUuid = categoryUuid
    ..kind = kind;
}

void main() {
  group('search', () {
    test('matches a hit in the description', () {
      final filter = TransactionFilter(query: 'brot');

      expect(filter.matches(_tx(description: 'Brotladen')), isTrue);
    });

    test('matches a hit in the counterparty', () {
      final filter = TransactionFilter(query: 'rewe');

      expect(filter.matches(_tx(counterparty: 'REWE Markt')), isTrue);
    });

    test('matches a hit in the merchant', () {
      final filter = TransactionFilter(query: 'paypal');

      expect(filter.matches(_tx(merchant: 'PayPal Europe')), isTrue);
    });

    test('matches a hit in the note', () {
      final filter = TransactionFilter(query: 'geschenk');

      expect(filter.matches(_tx(note: 'Geschenk für Anna')), isTrue);
    });

    test('matches the plain amount spelling', () {
      final filter = TransactionFilter(query: '104,97');

      expect(filter.matches(_tx(amountCents: -10497)), isTrue);
    });

    test('matches both the grouped and the plain amount spelling', () {
      final tx = _tx(amountCents: -123456);

      expect(TransactionFilter(query: '1.234,56').matches(tx), isTrue);
      expect(TransactionFilter(query: '1234,56').matches(tx), isTrue);
    });

    test('is case-insensitive', () {
      final filter = TransactionFilter(query: 'rewe');

      expect(filter.matches(_tx(counterparty: 'REWE')), isTrue);
    });

    test('umlauts stay literal (ticket 038)', () {
      final tx = _tx(description: 'Brühe');

      expect(TransactionFilter(query: 'Bruehe').matches(tx), isFalse);
      expect(TransactionFilter(query: 'brühe').matches(tx), isTrue);
    });

    test('an empty or whitespace-only query matches everything', () {
      final tx = _tx();

      expect(const TransactionFilter().matches(tx), isTrue);
      expect(TransactionFilter(query: '   ').matches(tx), isTrue);
    });
  });

  group('CategoryFilter.without', () {
    const filter = TransactionFilter(category: CategoryFilter.without());

    test('keeps an uncategorized regular booking', () {
      expect(filter.matches(_tx(categoryUuid: null)), isTrue);
    });

    test('drops a booking that has a category', () {
      expect(filter.matches(_tx(categoryUuid: 'cat-1')), isFalse);
    });

    test('drops an uncategorized transfer (ticket 049)', () {
      final tx = _tx(categoryUuid: null, kind: TransactionKind.transfer);

      expect(filter.matches(tx), isFalse);
    });
  });

  group('CategoryFilter.subtree', () {
    final filter = TransactionFilter(
      category: CategoryFilter.subtree(
        rootUuid: 'root-1',
        uuids: const {'root-1', 'child-1'},
      ),
    );

    test('keeps a booking whose category is in the subtree', () {
      expect(filter.matches(_tx(categoryUuid: 'child-1')), isTrue);
    });

    test('drops a booking whose category is outside the subtree', () {
      expect(filter.matches(_tx(categoryUuid: 'other')), isFalse);
    });

    test('drops an uncategorized booking', () {
      expect(filter.matches(_tx(categoryUuid: null)), isFalse);
    });
  });

  test('search and category combine by AND', () {
    final filter = TransactionFilter(
      query: 'REWE',
      category: CategoryFilter.subtree(
        rootUuid: 'a',
        uuids: const {'a'},
      ),
    );

    final matchesOnlySearch = _tx(counterparty: 'REWE', categoryUuid: 'b');
    final matchesOnlyCategory = _tx(counterparty: 'Bahn', categoryUuid: 'a');
    final matchesBoth = _tx(counterparty: 'REWE', categoryUuid: 'a');

    expect(filter.matches(matchesOnlySearch), isFalse);
    expect(filter.matches(matchesOnlyCategory), isFalse);
    expect(filter.matches(matchesBoth), isTrue);
  });

  group('isActive', () {
    test('is false for the default filter', () {
      expect(const TransactionFilter().isActive, isFalse);
    });

    test('is true once a query is set', () {
      expect(const TransactionFilter(query: 'x').isActive, isTrue);
    });

    test('is true once a non-all category is set', () {
      const filter = TransactionFilter(category: CategoryFilter.without());

      expect(filter.isActive, isTrue);
    });
  });

  test('apply returns the input list unchanged when inactive', () {
    final transactions = [_tx(), _tx(description: 'Zweite')];
    const filter = TransactionFilter();

    expect(filter.apply(transactions), same(transactions));
  });
}
