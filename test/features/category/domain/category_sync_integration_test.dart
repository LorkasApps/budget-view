import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/change_queue_entry.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/core/sync/sync_op.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_repository.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late CategoryRepository repo;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_catsync_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    repo = CategoryRepository(isar, sync, TransactionRepository(isar, sync));
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<List<ChangeQueueEntry>> queue() =>
      isar.changeQueueEntrys.where().findAll();

  test('every write enqueues one matching change-queue entry', () async {
    final category = await repo.save(Category()..name = 'Wohnen');
    category.name = 'Wohnen & Nebenkosten';
    await repo.save(category);
    await repo.delete(category.uuid);
    await repo.restore(category.uuid);

    final entries = await queue();

    expect(entries.map((entry) => entry.op).toList(), [
      SyncOp.create,
      SyncOp.update,
      SyncOp.delete,
      SyncOp.update,
    ]);
    expect(entries.every((entry) => entry.entityType == 'category'), isTrue);
    expect(
      entries.every((entry) => entry.entityUuid == category.uuid),
      isTrue,
    );
  });

  test('a rejected save enqueues nothing', () async {
    await expectLater(
      repo.save(Category()..name = ''),
      throwsA(isA<CategoryInvalid>()),
    );

    expect(await queue(), isEmpty);
  });

  test('a blocked delete enqueues nothing', () async {
    final parent = await repo.save(Category()..name = 'Wohnen');
    await repo.save(
      Category()
        ..name = 'Strom'
        ..parentUuid = parent.uuid,
    );
    final before = (await queue()).length;

    await expectLater(
      repo.delete(parent.uuid),
      throwsA(isA<CategoryDeleteBlocked>()),
    );

    expect(await queue(), hasLength(before));
  });

  test('reorderSiblings only enqueues rows whose order actually changed',
      () async {
    final first = await repo.save(
      Category()
        ..name = 'A'
        ..sortOrder = 1000,
    );
    final second = await repo.save(
      Category()
        ..name = 'B'
        ..sortOrder = 2000,
    );
    final before = (await queue()).length;

    // Already in this order: nothing to write.
    await repo.reorderSiblings([first, second]);
    expect(await queue(), hasLength(before));

    await repo.reorderSiblings([second, first]);
    final added = (await queue()).skip(before).toList();
    expect(added, hasLength(2));
    expect(added.every((entry) => entry.op == SyncOp.update), isTrue);
  });
}
