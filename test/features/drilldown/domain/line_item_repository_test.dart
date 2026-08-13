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

Transaction _tx({
  String accountUuid = 'acc-1',
  int amountCents = -4732,
  String description = 'REWE Einkauf',
}) {
  return Transaction()
    ..accountUuid = accountUuid
    ..amountCents = amountCents
    ..bookingDate = DateTime(2026, 8, 1)
    ..description = description;
}

LineItem _item({
  required String transactionUuid,
  int amountCents = -119,
  String description = 'Milch',
  double? quantity,
  int? unitPriceCents,
  int orderIndex = 0,
}) {
  return LineItem()
    ..transactionUuid = transactionUuid
    ..amountCents = amountCents
    ..description = description
    ..quantity = quantity
    ..unitPriceCents = unitPriceCents
    ..orderIndex = orderIndex;
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
    tempDir = await Directory.systemTemp.createTemp('budgetview_lineitem_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    transactions = TransactionRepository(isar, sync);
    repo = LineItemRepository(isar, sync, transactions);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Transaction> expenseParent({int amountCents = -4732}) =>
      transactions.save(_tx(amountCents: amountCents));

  Future<Transaction> refundParent({int amountCents = 3200}) =>
      transactions.save(_tx(amountCents: amountCents));

  /// Awaits [future], fails if it does not throw [LineItemInvalid], and
  /// asserts its German [message] otherwise.
  Future<void> expectRejected(
    Future<LineItem> future,
    String expectedMessage,
  ) async {
    try {
      await future;
      fail('expected a LineItemInvalid: $expectedMessage');
    } on LineItemInvalid catch (error) {
      expect(error.message, expectedMessage);
    }
  }

  test('save assigns uuid, timestamps and the first orderIndex', () async {
    final parent = await expenseParent();
    final saved = await repo.save(_item(transactionUuid: parent.uuid));

    expect(saved.uuid, isNotEmpty);
    expect(saved.createdAt, isNotNull);
    expect(saved.updatedAt, isNotNull);
    expect(saved.orderIndex, 1000);
  });

  test('a second line-item continues the orderIndex gap', () async {
    final parent = await expenseParent();
    await repo.save(
      _item(transactionUuid: parent.uuid, description: 'Milch'),
    );
    final second = await repo.save(
      _item(transactionUuid: parent.uuid, description: 'Brot'),
    );

    expect(second.orderIndex, 2000);
  });

  test('save rejects an empty description', () async {
    final parent = await expenseParent();
    await expectRejected(
      repo.save(_item(transactionUuid: parent.uuid, description: '')),
      'Beschreibung erforderlich',
    );
  });

  test('save rejects a description over the length limit', () async {
    final parent = await expenseParent();
    await expectRejected(
      repo.save(
        _item(transactionUuid: parent.uuid, description: 'A' * 121),
      ),
      'Beschreibung zu lang (max. 120 Zeichen)',
    );
  });

  test('save rejects a zero amount', () async {
    final parent = await expenseParent();
    await expectRejected(
      repo.save(_item(transactionUuid: parent.uuid, amountCents: 0)),
      'Betrag darf nicht 0 sein',
    );
  });

  test('save rejects a non-positive quantity', () async {
    final parent = await expenseParent();
    await expectRejected(
      repo.save(_item(transactionUuid: parent.uuid, quantity: 0)),
      'Menge muss größer als 0 sein',
    );
  });

  test('save rejects a non-positive unit price', () async {
    final parent = await expenseParent();
    await expectRejected(
      repo.save(_item(transactionUuid: parent.uuid, unitPriceCents: 0)),
      'Preis muss größer als 0 sein',
    );
  });

  test('save rejects a line-item whose transaction does not exist', () async {
    await expectRejected(
      repo.save(_item(transactionUuid: 'does-not-exist')),
      'Buchung existiert nicht',
    );
  });

  test('save rejects a positive amount under an expense parent', () async {
    final parent = await expenseParent();
    await expectRejected(
      repo.save(_item(transactionUuid: parent.uuid, amountCents: 500)),
      'Position einer Ausgabe muss negativ sein',
    );
  });

  test(
    'a refund parent accepts a positive line-item and rejects a negative one',
    () async {
      final parent = await refundParent();

      final saved = await repo.save(
        _item(transactionUuid: parent.uuid, amountCents: 1500),
      );
      expect(saved.uuid, isNotEmpty);

      await expectRejected(
        repo.save(_item(transactionUuid: parent.uuid, amountCents: -500)),
        'Position einer Einnahme muss positiv sein',
      );
    },
  );

  test('softDelete marks deleted and enqueues a delete', () async {
    final parent = await expenseParent();
    final saved = await repo.save(_item(transactionUuid: parent.uuid));
    await repo.softDelete(saved.uuid);

    expect((await repo.findByUuid(saved.uuid))!.deleted, isTrue);
    final ops = (await isar.changeQueueEntrys.where().findAll())
        .where((entry) => entry.entityType == 'lineItem')
        .map((entry) => entry.op)
        .toList();
    expect(ops, [SyncOp.create, SyncOp.delete]);
  });

  test('findByTransaction excludes deleted rows by default', () async {
    final parent = await expenseParent();
    final a = await repo.save(
      _item(transactionUuid: parent.uuid, description: 'A'),
    );
    await repo.save(_item(transactionUuid: parent.uuid, description: 'B'));
    await repo.softDelete(a.uuid);

    final active = await repo.findByTransaction(parent.uuid);
    expect(active.map((i) => i.description), ['B']);
  });

  test('findByTransaction includes deleted rows when asked', () async {
    final parent = await expenseParent();
    final a = await repo.save(
      _item(transactionUuid: parent.uuid, description: 'A'),
    );
    await repo.save(_item(transactionUuid: parent.uuid, description: 'B'));
    await repo.softDelete(a.uuid);

    final all = await repo.findByTransaction(
      parent.uuid,
      includeDeleted: true,
    );
    expect(all.length, 2);
  });

  test('findByTransaction sorts by orderIndex then createdAt', () async {
    final parent = await expenseParent();
    await repo.save(
      _item(
        transactionUuid: parent.uuid,
        description: 'C',
        orderIndex: 3000,
      ),
    );
    await repo.save(
      _item(
        transactionUuid: parent.uuid,
        description: 'A',
        orderIndex: 1000,
      ),
    );
    await repo.save(
      _item(
        transactionUuid: parent.uuid,
        description: 'B',
        orderIndex: 2000,
      ),
    );

    final ordered = await repo.findByTransaction(parent.uuid);
    expect(ordered.map((i) => i.description), ['A', 'B', 'C']);
  });

  test('sumForTransaction sums active rows only', () async {
    final parent = await expenseParent();
    await repo.save(
      _item(transactionUuid: parent.uuid, amountCents: -119),
    );
    await repo.save(
      _item(transactionUuid: parent.uuid, amountCents: -350),
    );
    final deleted = await repo.save(
      _item(transactionUuid: parent.uuid, amountCents: -9999),
    );
    await repo.softDelete(deleted.uuid);

    expect(await repo.sumForTransaction(parent.uuid), -469);
  });
}
