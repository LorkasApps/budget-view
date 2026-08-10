import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/data/local_balance_service.dart';
import 'package:budget_view/features/account/domain/account_repository.dart';

Account _account({required String name, required int openingBalanceCents}) {
  return Account()
    ..name = name
    ..type = AccountType.giro
    ..openingBalanceCents = openingBalanceCents
    ..openingDate = DateTime(2024, 1, 1);
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late AccountRepository repo;
  late LocalBalanceService service;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_balance_');
    isar = await openAppIsar(directory: tempDir.path);
    repo = AccountRepository(isar, LocalSyncAdapter(isar));
    service = LocalBalanceService(isar);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('watch emits opening balance as total (transactionSum 0)', () async {
    final acc = await repo.save(_account(name: 'Giro', openingBalanceCents: 5000));

    final balance = await service.watch(acc.uuid).first;
    expect(balance.openingBalanceCents, 5000);
    expect(balance.transactionSumCents, 0);
    expect(balance.totalCents, 5000);
  });

  test('watchTotalCents sums non-archived, excludes archived by default',
      () async {
    await repo.save(_account(name: 'A', openingBalanceCents: 1000));
    final b = await repo.save(_account(name: 'B', openingBalanceCents: 2500));

    expect(await service.watchTotalCents().first, 3500);

    await repo.softDelete(b.uuid);
    expect(await service.watchTotalCents().first, 1000);
    expect(await service.watchTotalCents(includeArchived: true).first, 3500);
  });

  test('watch of unknown account yields zero', () async {
    final balance = await service.watch('does-not-exist').first;
    expect(balance.totalCents, 0);
  });
}
