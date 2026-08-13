import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/change_queue_entry.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/core/sync/sync_op.dart';
import 'package:budget_view/features/drilldown/data/line_item.dart';
import 'package:budget_view/features/drilldown/domain/line_item_repository.dart';
import 'package:budget_view/features/drilldown/domain/restposten_reconciler.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

/// Guards on the auto-managed Restposten row: [LineItemRepository.save] and
/// [LineItemRepository.softDelete] must refuse it, while the reconciler-only
/// doors ([LineItemRepository.saveRestposten],
/// [LineItemRepository.removeRestposten]) and the user-owned
/// [LineItemRepository.updateRestpostenDetails] must work on it. Kept apart
/// from `line_item_repository_test.dart` (regular-row rules) and
/// `restposten_reconciler_test.dart` (gap math), since these scenarios are
/// about who is allowed to touch the row, not about the sum.
Transaction _tx({int amountCents = -5000}) {
  return Transaction()
    ..accountUuid = 'acc-1'
    ..amountCents = amountCents
    ..bookingDate = DateTime(2026, 8, 1)
    ..description = 'REWE Einkauf';
}

LineItem _item({
  required String transactionUuid,
  int amountCents = -1000,
  String description = 'Position',
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
  late RestpostenReconciler reconciler;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('budgetview_restposten_guard_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    transactions = TransactionRepository(isar, sync);
    repo = LineItemRepository(isar, sync, transactions);
    reconciler = LocalRestpostenReconciler(repo, transactions);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Transaction> parent({int amountCents = -5000}) =>
      transactions.save(_tx(amountCents: amountCents));

  /// The reconciler's own row, created by leaving an undershoot in place.
  Future<LineItem> restpostenRow(String transactionUuid) async {
    await reconciler.reconcile(transactionUuid);
    return (await repo.findRestposten(transactionUuid))!;
  }

  test('save refuses a manually-constructed restposten row', () async {
    final p = await parent();
    final row = LineItem()
      ..transactionUuid = p.uuid
      ..kind = LineItemKind.restposten
      ..amountCents = -1000
      ..description = 'Restposten';

    expect(
      () => repo.save(row),
      throwsA(isA<RestpostenNotManuallyModifiable>()),
    );
  });

  test('softDelete refuses the auto-managed row', () async {
    final p = await parent();
    await repo.save(_item(transactionUuid: p.uuid, amountCents: -1000));
    final managed = await restpostenRow(p.uuid);

    await expectLater(
      repo.softDelete(managed.uuid),
      throwsA(isA<RestpostenNotManuallyModifiable>()),
    );
    expect((await repo.findByUuid(managed.uuid))!.deleted, isFalse);
  });

  test('removeRestposten succeeds and enqueues a delete', () async {
    final p = await parent();
    await repo.save(_item(transactionUuid: p.uuid, amountCents: -1000));
    final managed = await restpostenRow(p.uuid);

    await repo.removeRestposten(managed.uuid);

    expect((await repo.findByUuid(managed.uuid))!.deleted, isTrue);
    final entries = await isar.changeQueueEntrys
        .filter()
        .entityUuidEqualTo(managed.uuid)
        .findAll();
    expect(entries.map((e) => e.op), contains(SyncOp.delete));
  });

  test(
    'saveRestposten accepts a sign-opposing amount that save would refuse '
    'for a regular row',
    () async {
      final p = await parent(amountCents: -5000);
      final row = LineItem()
        ..transactionUuid = p.uuid
        ..kind = LineItemKind.restposten
        ..amountCents = 500
        ..description = 'Restposten';

      final saved = await repo.saveRestposten(row);
      expect(saved.amountCents, 500);

      final regular = LineItem()
        ..transactionUuid = p.uuid
        ..amountCents = 500
        ..description = 'Gutschrift';
      // Unlike the restposten-kind guard above, this rejection comes from
      // `_write` (an `async` function), so it surfaces as a Future rejection
      // rather than a synchronous throw — hence `expectLater` on the call's
      // Future instead of wrapping it in a closure.
      await expectLater(
        repo.save(regular),
        throwsA(isA<LineItemInvalid>()),
      );
    },
  );

  test(
    'updateRestpostenDetails changes description and category, nothing else',
    () async {
      final p = await parent();
      await repo.save(_item(transactionUuid: p.uuid, amountCents: -1000));
      final managed = await restpostenRow(p.uuid);
      final beforeAmount = managed.amountCents;
      final beforeQuantity = managed.quantity;
      final beforeUnitPrice = managed.unitPriceCents;
      final beforeOrderIndex = managed.orderIndex;

      await repo.updateRestpostenDetails(
        managed.uuid,
        description: 'Pfandflasche',
        categoryUuid: 'cat-1',
      );

      final reloaded = await repo.findByUuid(managed.uuid);
      expect(reloaded!.description, 'Pfandflasche');
      expect(reloaded.categoryUuid, 'cat-1');
      expect(reloaded.amountCents, beforeAmount);
      expect(reloaded.quantity, beforeQuantity);
      expect(reloaded.unitPriceCents, beforeUnitPrice);
      expect(reloaded.orderIndex, beforeOrderIndex);
    },
  );

  test('updateRestpostenDetails rejects an empty description', () async {
    final p = await parent();
    await repo.save(_item(transactionUuid: p.uuid, amountCents: -1000));
    final managed = await restpostenRow(p.uuid);

    await expectLater(
      repo.updateRestpostenDetails(managed.uuid, description: ''),
      throwsA(isA<LineItemInvalid>()),
    );
  });

  test('findRestposten ignores a soft-deleted managed row', () async {
    final p = await parent();
    await repo.save(_item(transactionUuid: p.uuid, amountCents: -1000));
    final managed = await restpostenRow(p.uuid);
    await repo.removeRestposten(managed.uuid);

    expect(await repo.findRestposten(p.uuid), isNull);
  });
}
