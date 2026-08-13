import '../../transaction/domain/transaction_repository.dart';
import '../data/line_item.dart';
import 'line_item_repository.dart';

/// Keeps `sum(positions) == transaction.amountCents` by maintaining at most one
/// auto-managed `restposten` position per booking.
abstract class RestpostenReconciler {
  /// Called after any line-item write, and after the booking's amount changes.
  Future<void> reconcile(String transactionUuid);
}

class LocalRestpostenReconciler implements RestpostenReconciler {
  LocalRestpostenReconciler(this._lineItems, this._transactions);

  final LineItemRepository _lineItems;
  final TransactionRepository _transactions;

  /// Rounding noise, not a gap worth a row of its own.
  static const toleranceCents = 1;

  static const defaultDescription = 'Restposten';

  static const _orderIndexGap = 1000;

  @override
  Future<void> reconcile(String transactionUuid) async {
    final parent = await _transactions.findByUuid(transactionUuid);
    if (parent == null) return;

    final regular = (await _lineItems.findByTransaction(transactionUuid))
        .where((item) => item.kind == LineItemKind.regular)
        .toList();
    final existing = await _lineItems.findRestposten(transactionUuid);

    // Nothing to reconcile against: the booking's own amount is authoritative.
    if (regular.isEmpty) {
      if (existing != null) await _lineItems.removeRestposten(existing.uuid);
      return;
    }

    final covered = regular.fold<int>(0, (sum, item) => sum + item.amountCents);
    final gap = parent.amountCents - covered;

    if (gap.abs() <= toleranceCents) {
      if (existing != null) await _lineItems.removeRestposten(existing.uuid);
      return;
    }

    final row = existing ??
        (LineItem()
          ..transactionUuid = transactionUuid
          ..kind = LineItemKind.restposten
          ..description = defaultDescription);
    row
      ..amountCents = gap
      ..quantity = null
      ..unitPriceCents = null
      ..orderIndex = _bottomOrderIndex(regular);

    await _lineItems.saveRestposten(row);
  }

  /// Pinned below the user's positions, also after a reorder moved them.
  int _bottomOrderIndex(List<LineItem> regular) {
    final highest = regular.fold<int>(
      0,
      (max, item) => item.orderIndex > max ? item.orderIndex : max,
    );
    return highest + _orderIndexGap;
  }
}
