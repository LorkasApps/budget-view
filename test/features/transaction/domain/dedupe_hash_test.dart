import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/dedupe_hash.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx({
  int amountCents = -1299,
  DateTime? bookingDate,
  String counterparty = 'REWE Markt GmbH',
  String description = 'Einkauf',
}) {
  return Transaction()
    ..accountUuid = 'account-1'
    ..amountCents = amountCents
    ..bookingDate = bookingDate ?? DateTime(2026, 8, 3)
    ..description = description
    ..counterparty = counterparty;
}

void main() {
  test('is a 64-char hex digest and deterministic', () {
    final hash = computeDedupeHash(_tx());

    expect(hash, hasLength(64));
    expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(hash, computeDedupeHash(_tx()));
  });

  test('ignores the time component of the booking date', () {
    final morning = computeDedupeHash(
      _tx(bookingDate: DateTime(2026, 8, 3, 7, 15)),
    );
    final evening = computeDedupeHash(
      _tx(bookingDate: DateTime(2026, 8, 3, 22, 45)),
    );

    expect(morning, evening);
  });

  test('ignores case and whitespace differences in the counterparty', () {
    expect(
      computeDedupeHash(_tx(counterparty: 'REWE Markt GmbH')),
      computeDedupeHash(_tx(counterparty: '  rewe   markt  gmbh ')),
    );
  });

  test('ignores the description entirely', () {
    expect(
      computeDedupeHash(_tx(description: 'Einkauf')),
      computeDedupeHash(_tx(description: 'Etwas ganz anderes')),
    );
  });

  test('changes with amount, day or counterparty', () {
    final base = computeDedupeHash(_tx());

    expect(computeDedupeHash(_tx(amountCents: -1300)), isNot(base));
    expect(
      computeDedupeHash(_tx(bookingDate: DateTime(2026, 8, 4))),
      isNot(base),
    );
    expect(computeDedupeHash(_tx(counterparty: 'EDEKA')), isNot(base));
  });

  test('an empty counterparty stays empty, so such rows do collide', () {
    final first = computeDedupeHash(_tx(counterparty: '', description: 'A'));
    final second = computeDedupeHash(_tx(counterparty: '', description: 'B'));

    expect(first, second);
  });
}
