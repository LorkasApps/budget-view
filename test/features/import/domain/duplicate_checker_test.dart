import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/import/data/imported_source.dart';
import 'package:budget_view/features/import/data/imported_source_kind.dart';
import 'package:budget_view/features/import/domain/duplicate_checker.dart';
import 'package:budget_view/features/import/domain/imported_source_repository.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late TransactionRepository transactions;
  late ImportedSourceRepository sources;
  late LocalDuplicateChecker checker;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_dupe_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    transactions = TransactionRepository(isar, sync);
    sources = ImportedSourceRepository(isar, sync);
    checker = LocalDuplicateChecker(transactions, sources);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<Transaction> saveTx({
    String accountUuid = 'account-1',
    int amountCents = -1299,
    String counterparty = 'REWE',
  }) {
    return transactions.save(
      Transaction()
        ..accountUuid = accountUuid
        ..amountCents = amountCents
        ..bookingDate = DateTime(2026, 8, 3)
        ..description = 'Einkauf'
        ..counterparty = counterparty,
    );
  }

  test('finds an identical booking on the same account', () async {
    final first = await saveTx();
    await saveTx();

    final matches = await checker.findTransactionMatches(
      first.dedupeHash,
      accountUuid: 'account-1',
    );

    expect(matches, hasLength(2));
  });

  test('does not match across accounts, so transfers stay distinct', () async {
    final first = await saveTx();
    await saveTx(accountUuid: 'account-2');

    final matches = await checker.findTransactionMatches(
      first.dedupeHash,
      accountUuid: 'account-2',
    );

    expect(matches, hasLength(1));
    expect(matches.single.accountUuid, 'account-2');
  });

  test('a differing amount is not a match', () async {
    final first = await saveTx();
    await saveTx(amountCents: -1300);

    final matches = await checker.findTransactionMatches(
      first.dedupeHash,
      accountUuid: 'account-1',
    );

    expect(matches, hasLength(1));
  });

  test('soft-deleted bookings are excluded unless asked for', () async {
    final first = await saveTx();
    final second = await saveTx();
    await transactions.softDelete(second.uuid);

    expect(
      await checker.findTransactionMatches(
        first.dedupeHash,
        accountUuid: 'account-1',
      ),
      hasLength(1),
    );
    expect(
      await checker.findTransactionMatches(
        first.dedupeHash,
        accountUuid: 'account-1',
        excludeDeleted: false,
      ),
      hasLength(2),
    );
  });

  test('editing a booking moves it to its new hash', () async {
    final transaction = await saveTx();
    final originalHash = transaction.dedupeHash;

    transaction.amountCents = -9999;
    await transactions.save(transaction);

    expect(transaction.dedupeHash, isNot(originalHash));
    expect(
      await checker.findTransactionMatches(
        originalHash,
        accountUuid: 'account-1',
      ),
      isEmpty,
    );
    expect(
      await checker.findTransactionMatches(
        transaction.dedupeHash,
        accountUuid: 'account-1',
      ),
      hasLength(1),
    );
  });

  test('finds previous imports of the same document, newest first', () async {
    await sources.save(
      ImportedSource()
        ..kind = ImportedSourceKind.pdf
        ..contentHashSha256 = 'doc-hash'
        ..filename = 'juli.pdf'
        ..importedAt = DateTime(2026, 7, 1),
    );
    await sources.save(
      ImportedSource()
        ..kind = ImportedSourceKind.pdf
        ..contentHashSha256 = 'doc-hash'
        ..filename = 'juli-nochmal.pdf'
        ..importedAt = DateTime(2026, 8, 1),
    );

    final matches = await checker.findDocumentMatches('doc-hash');

    expect(matches.map((row) => row.filename), [
      'juli-nochmal.pdf',
      'juli.pdf',
    ]);
  });

  test('an unseen document has no matches', () async {
    expect(await checker.findDocumentMatches('unseen'), isEmpty);
  });
}
