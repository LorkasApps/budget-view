import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/change_queue_entry.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/core/sync/sync_op.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';

Transaction _tx({
  String accountUuid = 'acc-1',
  int amountCents = -4732,
  DateTime? bookingDate,
  String description = 'REWE Einkauf',
  String counterparty = '',
}) {
  return Transaction()
    ..accountUuid = accountUuid
    ..amountCents = amountCents
    ..bookingDate = bookingDate ?? DateTime(2026, 8, 1)
    ..description = description
    ..counterparty = counterparty;
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late TransactionRepository repo;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_tx_');
    isar = await openAppIsar(directory: tempDir.path);
    repo = TransactionRepository(isar, LocalSyncAdapter(isar));
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('save assigns uuid + timestamps and enqueues a create', () async {
    final saved = await repo.save(_tx());

    expect(saved.uuid, isNotEmpty);
    expect(saved.createdAt, isNotNull);

    final queue = await isar.changeQueueEntrys.where().findAll();
    expect(queue.single.op, SyncOp.create);
    expect(queue.single.entityType, 'transaction');
    expect(queue.single.entityUuid, saved.uuid);
  });

  test('re-saving enqueues an update and persists changes', () async {
    final saved = await repo.save(_tx());
    saved.description = 'REWE Berlin';
    await repo.save(saved);

    final ops = (await isar.changeQueueEntrys.where().findAll())
        .map((e) => e.op)
        .toList();
    expect(ops, [SyncOp.create, SyncOp.update]);
    expect((await repo.findByUuid(saved.uuid))!.description, 'REWE Berlin');
  });

  test('softDelete marks deleted and enqueues a delete', () async {
    final saved = await repo.save(_tx());
    await repo.softDelete(saved.uuid);

    expect((await repo.findByUuid(saved.uuid))!.deleted, isTrue);
    final ops = (await isar.changeQueueEntrys.where().findAll())
        .map((e) => e.op)
        .toList();
    expect(ops, [SyncOp.create, SyncOp.delete]);
  });

  test('findByAccount filters by account and excludes deleted by default',
      () async {
    final a = await repo.save(_tx(description: 'A'));
    await repo.save(_tx(description: 'B'));
    await repo.save(_tx(accountUuid: 'acc-2', description: 'other'));
    await repo.softDelete(a.uuid);

    final active = await repo.findByAccount('acc-1');
    expect(active.map((t) => t.description), ['B']);

    final all = await repo.findByAccount('acc-1', includeDeleted: true);
    expect(all.length, 2);
  });

  test('findByAccount sorts newest bookingDate first', () async {
    await repo.save(_tx(description: 'old', bookingDate: DateTime(2026, 1, 1)));
    await repo.save(_tx(description: 'new', bookingDate: DateTime(2026, 8, 1)));

    final list = await repo.findByAccount('acc-1');
    expect(list.map((t) => t.description), ['new', 'old']);
  });

  test('sumForAccount sums active amounts only', () async {
    await repo.save(_tx(amountCents: -1000));
    await repo.save(_tx(amountCents: 250));
    final deleted = await repo.save(_tx(amountCents: -9999));
    await repo.softDelete(deleted.uuid);
    await repo.save(_tx(accountUuid: 'acc-2', amountCents: -500));

    expect(await repo.sumForAccount('acc-1'), -750);
    expect(await repo.sumForAccount('acc-2'), -500);
  });
}
