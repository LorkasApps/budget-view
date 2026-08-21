import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/data/local_balance_service.dart';
import 'package:budget_view/features/account/domain/account_repository.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';

Account _account({required String name, required int openingBalanceCents}) {
  return Account()
    ..name = name
    ..type = AccountType.giro
    ..openingBalanceCents = openingBalanceCents
    ..openingDate = DateTime(2024, 1, 1);
}

Transaction _tx({
  required String accountUuid,
  required int amountCents,
  TransactionKind kind = TransactionKind.regular,
}) {
  return Transaction()
    ..accountUuid = accountUuid
    ..amountCents = amountCents
    ..bookingDate = DateTime(2026, 8, 1)
    ..description = 'test'
    ..kind = kind;
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late AccountRepository accounts;
  late TransactionRepository transactions;
  late LocalBalanceService service;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_balance_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    accounts = AccountRepository(isar, sync);
    transactions = TransactionRepository(isar, sync);
    service = LocalBalanceService(isar, transactions);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('watch returns opening balance when there are no transactions',
      () async {
    final acc =
        await accounts.save(_account(name: 'Giro', openingBalanceCents: 5000));

    final balance = await service.watch(acc.uuid).first;
    expect(balance.openingBalanceCents, 5000);
    expect(balance.transactionSumCents, 0);
    expect(balance.totalCents, 5000);
  });

  test('watch adds the transaction sum, ignoring deleted ones', () async {
    final acc =
        await accounts.save(_account(name: 'Giro', openingBalanceCents: 10000));
    await transactions.save(_tx(accountUuid: acc.uuid, amountCents: -2500));
    await transactions.save(_tx(accountUuid: acc.uuid, amountCents: 500));
    final gone =
        await transactions.save(_tx(accountUuid: acc.uuid, amountCents: -9999));
    await transactions.softDelete(gone.uuid);

    final balance = await service.watch(acc.uuid).first;
    expect(balance.transactionSumCents, -2000);
    expect(balance.totalCents, 8000);
  });

  test('transactions of other accounts do not leak into the balance', () async {
    final a =
        await accounts.save(_account(name: 'A', openingBalanceCents: 1000));
    final b =
        await accounts.save(_account(name: 'B', openingBalanceCents: 1000));
    await transactions.save(_tx(accountUuid: b.uuid, amountCents: -700));

    expect((await service.watch(a.uuid).first).totalCents, 1000);
    expect((await service.watch(b.uuid).first).totalCents, 300);
  });

  test('watchTotalCents sums opening + transactions, excludes archived',
      () async {
    final a =
        await accounts.save(_account(name: 'A', openingBalanceCents: 1000));
    final b =
        await accounts.save(_account(name: 'B', openingBalanceCents: 2500));
    await transactions.save(_tx(accountUuid: a.uuid, amountCents: -300));
    await transactions.save(_tx(accountUuid: b.uuid, amountCents: 200));

    expect(await service.watchTotalCents().first, 3400);

    await accounts.softDelete(b.uuid);
    expect(await service.watchTotalCents().first, 700);
    expect(await service.watchTotalCents(includeArchived: true).first, 3400);
  });

  test('watch of unknown account yields zero', () async {
    final balance = await service.watch('does-not-exist').first;
    expect(balance.totalCents, 0);
  });

  // Unlike the report, the balance has no exclusion for transfers: the money
  // really left (or arrived), so it must count here.
  test('a transfer still counts towards the balance', () async {
    final acc =
        await accounts.save(_account(name: 'Giro', openingBalanceCents: 5000));
    await transactions.save(
      _tx(
        accountUuid: acc.uuid,
        amountCents: -1500,
        kind: TransactionKind.transfer,
      ),
    );

    final balance = await service.watch(acc.uuid).first;
    expect(balance.transactionSumCents, -1500);
    expect(balance.totalCents, 3500);
  });
}
