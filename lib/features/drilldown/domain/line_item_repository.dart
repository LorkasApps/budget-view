import 'package:isar_community/isar.dart';

import '../../../core/sync/sync_adapter.dart';
import '../../../core/sync/sync_op.dart';
import '../../../core/sync/syncable_entity.dart';
import '../../transaction/domain/transaction_repository.dart';
import '../data/line_item.dart';
import 'line_item_validation.dart';

/// Thrown by [LineItemRepository.save] on a rule the sheet should have caught.
/// [message] is German and user-facing.
class LineItemInvalid implements Exception {
  LineItemInvalid(this.message);

  final String message;

  @override
  String toString() => 'LineItemInvalid: $message';
}

/// Thrown when a UI path tries to write or delete the auto-managed Restposten
/// row. Only the reconciler may, through its own doors on the repository.
class RestpostenNotManuallyModifiable implements Exception {
  const RestpostenNotManuallyModifiable();

  String get message => 'Der Restposten wird automatisch verwaltet.';

  @override
  String toString() => 'RestpostenNotManuallyModifiable: $message';
}

/// Persists [LineItem]s and mirrors every write to the sync change-queue, per
/// the repository-layer contract in docs/sync.md.
///
/// Injects [TransactionRepository] to resolve the parent booking: a line-item's
/// sign must follow its transaction's. Narrow Drilldown → Transaction edge, see
/// docs/dependencies.md.
class LineItemRepository {
  LineItemRepository(this._isar, this._sync, this._transactions);

  final Isar _isar;
  final SyncAdapter _sync;
  final TransactionRepository _transactions;

  static const _orderIndexGap = 1000;

  /// Persists a user-owned position. Refuses the auto-managed Restposten row —
  /// the reconciler owns that one via [saveRestposten].
  Future<LineItem> save(LineItem item) {
    if (item.kind == LineItemKind.restposten) {
      throw const RestpostenNotManuallyModifiable();
    }
    return _write(item, enforceParentSign: true);
  }

  /// Reconciler-only door for the Restposten row.
  ///
  /// Skips the parent-sign rule on purpose: when the user's positions overshoot
  /// the booking total, the closing gap legitimately points the other way (−50
  /// booking, −55 in positions → +5 Restposten).
  ///
  /// Dart has no package-private visibility, so this cannot be locked to the
  /// reconciler by the compiler — [save] refusing `restposten` is what keeps UI
  /// paths out, and a test guards it.
  Future<LineItem> saveRestposten(LineItem item) {
    assert(item.kind == LineItemKind.restposten);
    return _write(item, enforceParentSign: false);
  }

  Future<LineItem> _write(
    LineItem item, {
    required bool enforceParentSign,
  }) async {
    final descriptionError = LineItemValidation.description(item.description);
    if (descriptionError != null) throw LineItemInvalid(descriptionError);
    if (item.amountCents == 0) {
      throw LineItemInvalid('Betrag darf nicht 0 sein');
    }
    final quantityError = LineItemValidation.quantity(item.quantity);
    if (quantityError != null) throw LineItemInvalid(quantityError);
    final unitPriceError = LineItemValidation.unitPrice(item.unitPriceCents);
    if (unitPriceError != null) throw LineItemInvalid(unitPriceError);

    final parent = await _transactions.findByUuid(item.transactionUuid);
    if (parent == null) {
      throw LineItemInvalid('Buchung existiert nicht');
    }
    if (enforceParentSign &&
        parent.amountCents.isNegative != item.amountCents.isNegative) {
      throw LineItemInvalid(
        parent.amountCents.isNegative
            ? 'Position einer Ausgabe muss negativ sein'
            : 'Position einer Einnahme muss positiv sein',
      );
    }

    item.description = item.description.trim();
    final isNew = item.uuid.isEmpty;
    item.ensureUuid();
    final now = DateTime.now();
    if (isNew) {
      item.createdAt = now;
      if (item.orderIndex == 0) {
        item.orderIndex = await _nextOrderIndex(item.transactionUuid);
      }
    }
    item.updatedAt = now;

    await _isar.writeTxn(() async {
      await _isar.lineItems.put(item);
    });
    await _sync.enqueue(isNew ? SyncOp.create : SyncOp.update, item);
    return item;
  }

  Future<void> softDelete(String uuid) async {
    final item = await findByUuid(uuid);
    if (item == null || item.deleted) return;
    if (item.kind == LineItemKind.restposten) {
      throw const RestpostenNotManuallyModifiable();
    }
    await _markDeleted(item);
  }

  /// Reconciler-only door: the Restposten row disappears once the gap closes.
  Future<void> removeRestposten(String uuid) async {
    final item = await findByUuid(uuid);
    if (item == null || item.deleted) return;
    await _markDeleted(item);
  }

  /// The two fields a user may own on the auto-managed row. Amount, quantity,
  /// unit price and order stay with the reconciler.
  Future<void> updateRestpostenDetails(
    String uuid, {
    required String description,
    String? categoryUuid,
  }) async {
    final item = await findByUuid(uuid);
    if (item == null) return;
    final error = LineItemValidation.description(description);
    if (error != null) throw LineItemInvalid(error);

    item
      ..description = description.trim()
      ..categoryUuid = categoryUuid
      ..updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.lineItems.put(item);
    });
    await _sync.enqueue(SyncOp.update, item);
  }

  Future<void> _markDeleted(LineItem item) async {
    item.deleted = true;
    item.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.lineItems.put(item);
    });
    await _sync.enqueue(SyncOp.delete, item);
  }

  /// The active Restposten row of one booking, if the reconciler created one.
  Future<LineItem?> findRestposten(String transactionUuid) => _isar.lineItems
      .filter()
      .transactionUuidEqualTo(transactionUuid)
      .kindEqualTo(LineItemKind.restposten)
      .deletedEqualTo(false)
      .findFirst();

  Future<LineItem?> findByUuid(String uuid) =>
      _isar.lineItems.filter().uuidEqualTo(uuid).findFirst();

  /// Positions of one booking, in manual order.
  Future<List<LineItem>> findByTransaction(
    String transactionUuid, {
    bool includeDeleted = false,
  }) {
    if (includeDeleted) {
      return _isar.lineItems
          .filter()
          .transactionUuidEqualTo(transactionUuid)
          .sortByOrderIndex()
          .thenByCreatedAt()
          .findAll();
    }
    return _isar.lineItems
        .filter()
        .transactionUuidEqualTo(transactionUuid)
        .deletedEqualTo(false)
        .sortByOrderIndex()
        .thenByCreatedAt()
        .findAll();
  }

  /// Rewrites [ordered] into evenly spaced [LineItem.orderIndex] values. Only
  /// rows whose index actually changes are written and enqueued.
  Future<void> reorder(List<LineItem> ordered) async {
    final changed = <LineItem>[];
    final now = DateTime.now();
    for (var i = 0; i < ordered.length; i++) {
      final item = ordered[i];
      final index = (i + 1) * _orderIndexGap;
      if (item.orderIndex == index) continue;
      item.orderIndex = index;
      item.updatedAt = now;
      changed.add(item);
    }
    if (changed.isEmpty) return;
    await _isar.writeTxn(() async {
      await _isar.lineItems.putAll(changed);
    });
    for (final item in changed) {
      await _sync.enqueue(SyncOp.update, item);
    }
  }

  /// Sum of active positions, signed like the parent booking.
  Future<int> sumForTransaction(String transactionUuid) async {
    final items = await findByTransaction(transactionUuid);
    return items.fold<int>(0, (sum, item) => sum + item.amountCents);
  }

  Future<int> _nextOrderIndex(String transactionUuid) async {
    final last = await _isar.lineItems
        .filter()
        .transactionUuidEqualTo(transactionUuid)
        .sortByOrderIndexDesc()
        .findFirst();
    return (last?.orderIndex ?? 0) + _orderIndexGap;
  }
}
