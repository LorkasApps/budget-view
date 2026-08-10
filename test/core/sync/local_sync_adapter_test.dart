import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/change_queue_entry.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/core/sync/sync_op.dart';
import 'package:budget_view/core/sync/syncable_entity.dart';

class _FakeEntity implements SyncableEntity {
  _FakeEntity(this.uuid);

  @override
  String uuid;

  @override
  String get entityType => 'fake';

  @override
  Map<String, dynamic> toSyncPayload() => {'uuid': uuid};
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late LocalSyncAdapter adapter;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_sync_');
    isar = await openAppIsar(directory: tempDir.path);
    adapter = LocalSyncAdapter(isar);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('enqueue writes one change-queue entry per op', () async {
    await adapter.enqueue(SyncOp.create, _FakeEntity('u1'));
    await adapter.enqueue(SyncOp.update, _FakeEntity('u1'));
    await adapter.enqueue(SyncOp.delete, _FakeEntity('u1'));

    final all = await isar.changeQueueEntrys.where().findAll();
    expect(all.length, 3);
    expect(all.map((e) => e.op), containsAll(SyncOp.values));
    expect(all.every((e) => e.entityType == 'fake'), isTrue);
    expect(all.every((e) => !e.processed), isTrue);
  });

  test('sync drains pending entries and reports the count', () async {
    await adapter.enqueue(SyncOp.create, _FakeEntity('u1'));
    await adapter.enqueue(SyncOp.create, _FakeEntity('u2'));

    final result = await adapter.sync();
    expect(result.processed, 2);

    final stillPending =
        await isar.changeQueueEntrys.filter().processedEqualTo(false).findAll();
    expect(stillPending, isEmpty);
  });

  test('sync on empty queue processes zero', () async {
    final result = await adapter.sync();
    expect(result.processed, 0);
  });

  test('ensureUuid assigns a v4 uuid only when empty', () async {
    final blank = _FakeEntity('');
    blank.ensureUuid();
    expect(blank.uuid, isNotEmpty);

    final preset = _FakeEntity('keep-me');
    preset.ensureUuid();
    expect(preset.uuid, 'keep-me');
  });
}
