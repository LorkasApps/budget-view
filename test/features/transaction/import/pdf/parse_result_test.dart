import 'package:budget_view/features/transaction/import/candidate_conversion.dart';
import 'package:budget_view/features/transaction/import/pdf/parse_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ParseResult defaults to no warnings and no statement balance', () {
    const result = ParseResult(transactions: []);

    expect(result.transactions, isEmpty);
    expect(result.warnings, isEmpty);
    expect(result.statementBalanceCents, isNull);
  });

  test('candidate keeps signed amount, value date and raw debug data', () {
    final candidate = ParsedTransactionCandidate(
      bookingDate: DateTime(2026, 8, 3),
      valueDate: DateTime(2026, 8, 4),
      amountCents: -1299,
      description: 'REWE SAGT DANKE',
      counterparty: 'REWE Markt GmbH',
      raw: const {'line': '03.08. REWE SAGT DANKE -12,99'},
    );

    expect(candidate.amountCents, -1299);
    expect(candidate.valueDate, DateTime(2026, 8, 4));
    expect(candidate.raw['line'], '03.08. REWE SAGT DANKE -12,99');
  });

  test('candidateToTransaction maps onto an unsaved transaction', () {
    final candidate = ParsedTransactionCandidate(
      bookingDate: DateTime(2026, 8, 3),
      amountCents: -1299,
      description: 'REWE SAGT DANKE',
      counterparty: 'REWE Markt GmbH',
    );

    final transaction = candidateToTransaction(
      candidate,
      accountUuid: 'account-1',
    );

    expect(transaction.uuid, isEmpty);
    expect(transaction.accountUuid, 'account-1');
    expect(transaction.amountCents, -1299);
    expect(transaction.bookingDate, DateTime(2026, 8, 3));
    expect(transaction.description, 'REWE SAGT DANKE');
    expect(transaction.counterparty, 'REWE Markt GmbH');
    expect(transaction.note, isEmpty);
    expect(transaction.deleted, isFalse);
  });

  test('candidateToTransaction defaults a missing counterparty to empty', () {
    final candidate = ParsedTransactionCandidate(
      bookingDate: DateTime(2026, 8, 3),
      amountCents: 5000,
      description: 'GEHALT',
    );

    final transaction = candidateToTransaction(
      candidate,
      accountUuid: 'account-1',
    );

    expect(transaction.counterparty, isEmpty);
    expect(transaction.amountCents, 5000);
  });
}
