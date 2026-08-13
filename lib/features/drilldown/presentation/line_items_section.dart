import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../category/presentation/category_chip.dart';
import '../data/line_item.dart';
import '../domain/line_item_providers.dart';
import '../domain/line_item_validation.dart';
import 'line_item_edit_sheet.dart';

/// Positions of one booking: reorderable list, live subtotal, add button.
///
/// Only rendered for a persisted booking — a position needs its parent's uuid.
/// The subtotal is informational here; ticket 019 owns sum validation.
class LineItemsSection extends ConsumerWidget {
  const LineItemsSection({
    super.key,
    required this.transactionUuid,
    required this.parentIsExpense,
  });

  final String transactionUuid;
  final bool parentIsExpense;

  Future<void> _add(BuildContext context) => showLineItemSheet(
        context,
        transactionUuid: transactionUuid,
        parentIsExpense: parentIsExpense,
      );

  Future<void> _edit(BuildContext context, LineItem item) => showLineItemSheet(
        context,
        transactionUuid: transactionUuid,
        parentIsExpense: parentIsExpense,
        existing: item,
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

  void _reorder(WidgetRef ref, List<LineItem> items, int oldIndex, int newIndex) {
    final reordered = [...items];
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    reordered.insert(target, reordered.removeAt(oldIndex));
    ref.read(lineItemRepositoryProvider).reorder(reordered);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(lineItemsProvider(transactionUuid));

    return itemsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('Positionen nicht ladbar: $error'),
      data: (items) {
        final subtotal = items.fold<int>(0, (sum, i) => sum + i.amountCents);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Positionen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (items.isNotEmpty)
                  Text(
                    'Σ ${formatCentsEur(subtotal)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
              ],
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
                    onDismissed: (_) => ref
                        .read(lineItemRepositoryProvider)
                        .softDelete(item.uuid),
                    child: _LineItemRow(
                      item: item,
                      index: index,
                      onTap: () => _edit(context, item),
                    ),
                  );
                },
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add),
                label: const Text('Position'),
              ),
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
    required this.index,
    required this.onTap,
  });

  final LineItem item;
  final int index;
  final VoidCallback onTap;

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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.description),
      subtitle: quantityLine == null ? null : Text(quantityLine),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.categoryUuid != null)
            CategoryChip(categoryUuid: item.categoryUuid),
          const SizedBox(width: 8),
          Text(formatCentsEur(item.amountCents)),
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
