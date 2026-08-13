import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/change_queue_entry.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/core/sync/sync_op.dart';
import 'package:budget_view/features/drilldown/data/line_item.dart';
import 'package:budget_view/features/drilldown/domain/line_item_repository.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

Transaction _tx() {
  return Transaction()
    ..accountUuid = 'acc-1'
    ..amountCents = -4732
    ..bookingDate = DateTime(2026, 8, 1)
    ..description = 'REWE Einkauf';
}

LineItem _item(String transactionUuid, String description) {
  return LineItem()
    ..transactionUuid = transactionUuid
    ..amountCents = -119
    ..description = description;
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late TransactionRepository transactions;
  late LineItemRepository repo;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_lineitemreorder_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    transactions = TransactionRepository(isar, sync);
    repo = LineItemRepository(isar, sync, transactions);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<List<ChangeQueueEntry>> queue() =>
      isar.changeQueueEntrys.where().findAll();

  test(
    'reorder persists evenly spaced orderIndex values in the new order',
    () async {
      final parent = await transactions.save(_tx());
      final a = await repo.save(_item(parent.uuid, 'A'));
      final b = await repo.save(_item(parent.uuid, 'B'));
      final c = await repo.save(_item(parent.uuid, 'C'));
      // Created in this order: A=1000, B=2000, C=3000.

      await repo.reorder([c, a, b]);

      final ordered = await repo.findByTransaction(parent.uuid);
      expect(ordered.map((i) => i.description).toList(), ['C', 'A', 'B']);
      expect(ordered.map((i) => i.orderIndex).toList(), [1000, 2000, 3000]);
    },
  );

  test('reordering into the same order enqueues nothing', () async {
    final parent = await transactions.save(_tx());
    final a = await repo.save(_item(parent.uuid, 'A'));
    final b = await repo.save(_item(parent.uuid, 'B'));
    final before = (await queue()).length;

    await repo.reorder([a, b]);

    expect(await queue(), hasLength(before));
  });

  test('a row that keeps its position is not written or enqueued', () async {
    final parent = await transactions.save(_tx());
    final a = await repo.save(_item(parent.uuid, 'A'));
    final b = await repo.save(_item(parent.uuid, 'B'));
    final c = await repo.save(_item(parent.uuid, 'C'));
    // A stays first; only B and C swap places.
    final before = (await queue()).length;

    await repo.reorder([a, c, b]);

    final added = (await queue()).skip(before).toList();
    expect(added, hasLength(2));
    expect(added.every((entry) => entry.op == SyncOp.update), isTrue);
    expect(added.any((entry) => entry.entityUuid == a.uuid), isFalse);
  });
}
