import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/drilldown/data/line_item.dart';
import 'package:budget_view/features/drilldown/domain/line_item_repository.dart';
import 'package:budget_view/features/drilldown/domain/restposten_reconciler.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

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
        await Directory.systemTemp.createTemp('budgetview_restposten_');
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

  test(
    'creates a restposten row for the undershoot, pinned below the regulars',
    () async {
      final p = await parent(amountCents: -5000);
      final a = await repo.save(
        _item(transactionUuid: p.uuid, amountCents: -1000),
      );
      final b = await repo.save(
        _item(transactionUuid: p.uuid, amountCents: -1500),
      );
      final highestOrderIndex =
          a.orderIndex > b.orderIndex ? a.orderIndex : b.orderIndex;

      await reconciler.reconcile(p.uuid);

      final restposten = await repo.findRestposten(p.uuid);
      expect(restposten, isNotNull);
      expect(restposten!.amountCents, -2500);
      expect(restposten.kind, LineItemKind.restposten);
      expect(restposten.orderIndex, highestOrderIndex + 1000);
    },
  );

  test(
    'a second reconcile after the gap changes updates the same row instead '
    'of duplicating it',
    () async {
      final p = await parent(amountCents: -5000);
      await repo.save(_item(transactionUuid: p.uuid, amountCents: -1000));
      await reconciler.reconcile(p.uuid);
      final first = await repo.findRestposten(p.uuid);
      expect(first!.amountCents, -4000);

      await repo.save(_item(transactionUuid: p.uuid, amountCents: -500));
      await reconciler.reconcile(p.uuid);

      final all = await repo.findByTransaction(p.uuid, includeDeleted: true);
      final managedRows =
          all.where((i) => i.kind == LineItemKind.restposten).toList();
      expect(managedRows, hasLength(1));
      expect(managedRows.single.uuid, first.uuid);
      expect(managedRows.single.amountCents, -3500);
    },
  );

  test(
    'removes the restposten row once the positions cover the total',
    () async {
      final p = await parent(amountCents: -5000);
      await repo.save(_item(transactionUuid: p.uuid, amountCents: -2000));
      await reconciler.reconcile(p.uuid);
      expect(await repo.findRestposten(p.uuid), isNotNull);

      // Total now covers the parent exactly: -2000 + -3000 == -5000.
      await repo.save(
        _item(transactionUuid: p.uuid, amountCents: -3000, description: 'B'),
      );
      await reconciler.reconcile(p.uuid);

      expect(await repo.findRestposten(p.uuid), isNull);
    },
  );

  test(
    'a 1-cent gap is rounding noise, not a restposten-worthy shortfall',
    () async {
      final p = await parent(amountCents: -5000);
      await repo.save(_item(transactionUuid: p.uuid, amountCents: -4999));

      await reconciler.reconcile(p.uuid);

      expect(await repo.findRestposten(p.uuid), isNull);
    },
  );

  test(
    'removes the restposten row once the last regular position is deleted',
    () async {
      final p = await parent(amountCents: -5000);
      final a = await repo.save(
        _item(transactionUuid: p.uuid, amountCents: -1000),
      );
      await reconciler.reconcile(p.uuid);
      expect(await repo.findRestposten(p.uuid), isNotNull);

      await repo.softDelete(a.uuid);
      await reconciler.reconcile(p.uuid);

      expect(await repo.findRestposten(p.uuid), isNull);
    },
  );

  test(
    'an overshoot flips the restposten to the opposite sign of the parent',
    () async {
      final p = await parent(amountCents: -5000);
      await repo.save(_item(transactionUuid: p.uuid, amountCents: -5500));

      await reconciler.reconcile(p.uuid);

      final restposten = await repo.findRestposten(p.uuid);
      expect(restposten, isNotNull);
      expect(restposten!.amountCents, 500);
    },
  );

  test('reconciling an unknown transaction uuid is a silent no-op', () async {
    await expectLater(reconciler.reconcile('does-not-exist'), completes);
  });

  test('reconciling twice in a row is idempotent', () async {
    final p = await parent(amountCents: -5000);
    await repo.save(_item(transactionUuid: p.uuid, amountCents: -1000));

    await reconciler.reconcile(p.uuid);
    final first = await repo.findRestposten(p.uuid);

    await reconciler.reconcile(p.uuid);
    final second = await repo.findRestposten(p.uuid);

    expect(second!.uuid, first!.uuid);
    expect(second.amountCents, first.amountCents);
    final all = await repo.findByTransaction(p.uuid, includeDeleted: true);
    expect(
      all.where((i) => i.kind == LineItemKind.restposten),
      hasLength(1),
    );
  });

  test(
    'a soft-deleted regular position is excluded from the gap sum',
    () async {
      final p = await parent(amountCents: -5000);
      await repo.save(_item(transactionUuid: p.uuid, amountCents: -1000));
      final deletedItem = await repo.save(
        _item(transactionUuid: p.uuid, amountCents: -4000, description: 'B'),
      );
      await repo.softDelete(deletedItem.uuid);

      await reconciler.reconcile(p.uuid);

      final restposten = await repo.findRestposten(p.uuid);
      expect(restposten, isNotNull);
      // Only the active -1000 item counts, so the gap against -5000 is
      // -4000, not -1000.
      expect(restposten!.amountCents, -4000);
    },
  );
}
