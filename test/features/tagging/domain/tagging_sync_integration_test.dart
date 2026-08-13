import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/change_queue_entry.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/core/sync/sync_op.dart';
import 'package:budget_view/features/tagging/domain/tagging_rule_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late TaggingRuleRepository repo;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_tagsync_');
    isar = await openAppIsar(directory: tempDir.path);
    repo = TaggingRuleRepository(isar, LocalSyncAdapter(isar));
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // The change queue is shared with every entity in the app; filtering by
  // entityType keeps these assertions safe even if other tests grow to share
  // it (they do not today, but the repository test file next to this one
  // never enqueues anything else in this Isar instance).
  Future<List<ChangeQueueEntry>> queue() async {
    final all = await isar.changeQueueEntrys.where().findAll();
    return all.where((entry) => entry.entityType == 'taggingRule').toList();
  }

  test('the first upsert enqueues a create for the new rule', () async {
    final rule = await repo.upsert('rewe berlin', 'cat-groceries');

    final entries = await queue();
    expect(entries, hasLength(1));
    expect(entries.single.op, SyncOp.create);
    expect(entries.single.entityType, 'taggingRule');
    expect(entries.single.entityUuid, rule.uuid);
  });

  test('a second upsert of the same triple enqueues an update', () async {
    final rule = await repo.upsert('rewe berlin', 'cat-groceries');
    await repo.upsert('rewe berlin', 'cat-groceries');

    final entries = await queue();
    expect(entries.map((entry) => entry.op).toList(), [
      SyncOp.create,
      SyncOp.update,
    ]);
    expect(entries.last.entityUuid, rule.uuid);
  });

  test('delete enqueues a delete', () async {
    final rule = await repo.upsert('rewe berlin', 'cat-groceries');
    await repo.delete(rule.uuid);

    final entries = await queue();
    expect(entries.map((entry) => entry.op).toList(), [
      SyncOp.create,
      SyncOp.delete,
    ]);
    expect(entries.last.entityUuid, rule.uuid);
  });

  test('remap enqueues an update', () async {
    final rule = await repo.upsert('rewe berlin', 'cat-groceries');
    await repo.remap(rule.uuid, 'cat-drugstore');

    final entries = await queue();
    expect(entries.map((entry) => entry.op).toList(), [
      SyncOp.create,
      SyncOp.update,
    ]);
    expect(entries.last.entityUuid, rule.uuid);
  });
}
