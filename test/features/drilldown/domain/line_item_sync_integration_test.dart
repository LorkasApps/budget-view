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

Transaction _tx({int amountCents = -4732}) {
  return Transaction()
    ..accountUuid = 'acc-1'
    ..amountCents = amountCents
    ..bookingDate = DateTime(2026, 8, 1)
    ..description = 'REWE Einkauf';
}

LineItem _item({
  required String transactionUuid,
  int amountCents = -119,
  String description = 'Milch',
}) {
  return LineItem()
    ..transactionUuid = transactionUuid
    ..amountCents = amountCents
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
    tempDir = await Directory.systemTemp.createTemp('budgetview_lineitemsync_');
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
    'create, update and delete land in the change queue in order',
    () async {
      final parent = await transactions.save(_tx());
      final before = (await queue()).length;

      final saved = await repo.save(_item(transactionUuid: parent.uuid));
      saved.description = 'Milch 1,5%';
      await repo.save(saved);
      await repo.softDelete(saved.uuid);

      final entries = (await queue()).skip(before).toList();
      expect(
        entries.map((entry) => entry.op).toList(),
        [SyncOp.create, SyncOp.update, SyncOp.delete],
      );
      expect(
        entries.every((entry) => entry.entityType == 'lineItem'),
        isTrue,
      );
      expect(
        entries.every((entry) => entry.entityUuid == saved.uuid),
        isTrue,
      );
    },
  );

  test('a rejected save enqueues nothing', () async {
    final parent = await transactions.save(_tx());
    final before = (await queue()).length;

    await expectLater(
      repo.save(_item(transactionUuid: parent.uuid, description: '')),
      throwsA(isA<LineItemInvalid>()),
    );

    expect(await queue(), hasLength(before));
  });

  test('a rejected save from a sign mismatch enqueues nothing', () async {
    final parent = await transactions.save(_tx(amountCents: -4732));
    final before = (await queue()).length;

    await expectLater(
      repo.save(_item(transactionUuid: parent.uuid, amountCents: 500)),
      throwsA(isA<LineItemInvalid>()),
    );

    expect(await queue(), hasLength(before));
  });
}
