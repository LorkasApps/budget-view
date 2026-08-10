import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/change_queue_entry.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/core/sync/sync_op.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_repository.dart';

Account _account({
  String name = 'Giro',
  AccountType type = AccountType.giro,
  int openingBalanceCents = 10000,
}) {
  return Account()
    ..name = name
    ..type = type
    ..openingBalanceCents = openingBalanceCents
    ..openingDate = DateTime(2024, 1, 1);
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late AccountRepository repo;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_account_');
    isar = await openAppIsar(directory: tempDir.path);
    repo = AccountRepository(isar, LocalSyncAdapter(isar));
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('save assigns uuid + timestamps and enqueues a create', () async {
    final saved = await repo.save(_account());

    expect(saved.uuid, isNotEmpty);
    expect(saved.createdAt, isNotNull);
    expect(saved.updatedAt, isNotNull);

    final queue = await isar.changeQueueEntrys.where().findAll();
    expect(queue.length, 1);
    expect(queue.single.op, SyncOp.create);
    expect(queue.single.entityType, 'account');
    expect(queue.single.entityUuid, saved.uuid);
  });

  test('re-saving an existing account enqueues an update', () async {
    final saved = await repo.save(_account());
    saved.name = 'Giro DKB';
    await repo.save(saved);

    final ops =
        (await isar.changeQueueEntrys.where().findAll()).map((e) => e.op).toList();
    expect(ops, [SyncOp.create, SyncOp.update]);

    final reloaded = await repo.findByUuid(saved.uuid);
    expect(reloaded!.name, 'Giro DKB');
  });

  test('findAll excludes archived by default, includes when asked', () async {
    final a = await repo.save(_account(name: 'A'));
    await repo.save(_account(name: 'B'));
    await repo.softDelete(a.uuid);

    final active = await repo.findAll();
    expect(active.map((e) => e.name), ['B']);

    final all = await repo.findAll(includeArchived: true);
    expect(all.map((e) => e.name), ['A', 'B']);
  });

  test('softDelete archives and enqueues a delete', () async {
    final saved = await repo.save(_account());
    await repo.softDelete(saved.uuid);

    final reloaded = await repo.findByUuid(saved.uuid);
    expect(reloaded!.archived, isTrue);

    final ops =
        (await isar.changeQueueEntrys.where().findAll()).map((e) => e.op).toList();
    expect(ops, [SyncOp.create, SyncOp.delete]);
  });

  test('restore un-archives and enqueues an update', () async {
    final saved = await repo.save(_account());
    await repo.softDelete(saved.uuid);
    await repo.restore(saved.uuid);

    final reloaded = await repo.findByUuid(saved.uuid);
    expect(reloaded!.archived, isFalse);
  });
}
