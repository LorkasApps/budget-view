import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/text/normalize.dart';
import '../../analytics/presentation/item_price_chart_screen.dart';
import '../../category/presentation/category_chip.dart';
import '../../transaction/data/transaction.dart';
import '../data/line_item.dart';
import '../domain/category_resolver.dart';
import '../domain/line_item_providers.dart';
import '../domain/line_item_validation.dart';
import '../scan/presentation/receipt_scan_flow.dart';
import 'line_item_edit_sheet.dart';

/// Positions of one booking: reorderable list, live subtotal, add button.
///
/// Only rendered for a persisted booking — a position needs its parent's uuid.
/// The subtotal is informational here; ticket 019 owns sum validation.
class LineItemsSection extends ConsumerWidget {
  const LineItemsSection({super.key, required this.transaction});

  final Transaction transaction;

  Future<void> _add(BuildContext context) =>
      showLineItemSheet(context, parent: transaction);

  Future<void> _scan(BuildContext context, WidgetRef ref) =>
      startReceiptScan(context, ref, transaction);

  Future<void> _edit(BuildContext context, LineItem item) =>
      showLineItemSheet(context, parent: transaction, existing: item);

  /// Navigation-only edge into Analytics (see decisions.md), same shape as the
  /// long-press from a report row into the forecast: on a position the user
  /// already holds the item, so the search screen would only be a detour.
  void _openPriceHistory(BuildContext context, LineItem item) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ItemPriceChartScreen(
            normalizedKey: normalizeForMatching(item.description),
            title: item.description,
          ),
        ),
      );

  Future<bool> _confirmDelete(BuildContext context, LineItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Position löschen?'),
        content: Text(item.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Reorders the user's positions only; the reconciler re-pins the Restposten
  /// row to the bottom afterwards.
  Future<void> _reorder(
    WidgetRef ref,
    List<LineItem> items,
    int oldIndex,
    int newIndex,
  ) async {
    final reordered = [...items];
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    reordered.insert(target, reordered.removeAt(oldIndex));

    await ref.read(lineItemRepositoryProvider).reorder(
          reordered.where((item) => item.kind == LineItemKind.regular).toList(),
        );
    await ref.read(restpostenReconcilerProvider).reconcile(transaction.uuid);
  }

  Future<void> _delete(WidgetRef ref, LineItem item) async {
    await ref.read(lineItemRepositoryProvider).softDelete(item.uuid);
    await ref.read(restpostenReconcilerProvider).reconcile(transaction.uuid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(lineItemsProvider(transaction.uuid));

    return itemsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('Positionen nicht ladbar: $error'),
      data: (items) {
        final subtotal = items.fold<int>(0, (sum, i) => sum + i.amountCents);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Positionen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Noch keine Positionen erfasst.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ReorderableListView.builder(
                // Explicit handle: the default one would swallow the horizontal
                // swipe used for deleting.
                buildDefaultDragHandles: false,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                onReorderItem: (oldIndex, newIndex) =>
                    _reorder(ref, items, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final managed = item.kind == LineItemKind.restposten;
                  final row = _LineItemRow(
                    item: item,
                    parent: transaction,
                    index: index,
                    onTap: () => _edit(context, item),
                    // The Restposten is a difference, not an article, so it has
                    // no price history to open.
                    onLongPress: managed
                        ? null
                        : () => _openPriceHistory(context, item),
                  );
                  // The managed row has no swipe: the repository would refuse
                  // the delete anyway, and an animating-away row that comes
                  // back reads as a bug.
                  if (managed) {
                    return KeyedSubtree(key: ValueKey(item.uuid), child: row);
                  }
                  return Dismissible(
                    key: ValueKey(item.uuid),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const Icon(Icons.delete),
                    ),
                    confirmDismiss: (_) => _confirmDelete(context, item),
                    onDismissed: (_) => _delete(ref, item),
                    child: row,
                  );
                },
              ),
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Σ ${formatCentsEur(subtotal)} von '
                  '${formatCentsEur(transaction.amountCents)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Position'),
                ),
                TextButton.icon(
                  onPressed: () => _scan(context, ref),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Kassenbon scannen'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({
    required this.item,
    required this.parent,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  final LineItem item;
  final Transaction parent;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  String? get _quantityLine {
    final quantity = item.quantity;
    final unitPrice = item.unitPriceCents;
    if (quantity == null && unitPrice == null) return null;
    if (quantity == null) return '${formatCentsEur(unitPrice!)} / Einheit';
    if (unitPrice == null) return LineItemValidation.quantityLabel(quantity);
    return '${LineItemValidation.quantityLabel(quantity)} × '
        '${formatCentsEur(unitPrice)}';
  }

  @override
  Widget build(BuildContext context) {
    final quantityLine = _quantityLine;
    final managed = item.kind == LineItemKind.restposten;
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      textColor: managed ? theme.colorScheme.outline : null,
      title: Row(
        children: [
          Flexible(
            child: Text(item.description, overflow: TextOverflow.ellipsis),
          ),
          if (managed) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Restposten', style: theme.textTheme.labelSmall),
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          _CategoryBadge(item: item, parent: parent),
          if (quantityLine != null)
            Flexible(
              child: Text(
                ' · $quantityLine',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatCentsEur(item.amountCents)),
          // No handle on the managed row: its position is the reconciler's.
          if (!managed)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.drag_handle),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows the position's effective category: dimmed with an inherit arrow when
/// it falls back to the booking, plain when the position overrides it.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.item, required this.parent});

  final LineItem item;
  final Transaction parent;

  @override
  Widget build(BuildContext context) {
    final effective = effectiveCategoryUuid(item, parent);
    final chip = CategoryChip(categoryUuid: effective);

    if (!inheritsCategory(item)) return chip;

    return Opacity(
      opacity: 0.55,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.subdirectory_arrow_right, size: 14),
          const SizedBox(width: 2),
          chip,
        ],
      ),
    );
  }
}
