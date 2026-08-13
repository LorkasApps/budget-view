import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category_providers.dart';
import '../domain/category_tree.dart';
import 'category_style.dart';

/// Outcome of a pick.
///
/// [pickCategory] returning null means the sheet was dismissed; returning a
/// [CategoryPick] whose [uuid] is null means the user deliberately cleared the
/// category. Those two cases must stay distinguishable.
@immutable
class CategoryPick {
  const CategoryPick(this.uuid);

  final String? uuid;
}

/// Tree picker over the whole category tree; any node may be chosen, not just
/// leaves. Set [allowNone] where an empty category is legal.
///
/// [noneLabel] renames that first option where "none" means something more
/// specific — line-items use it to say they inherit from their booking.
Future<CategoryPick?> pickCategory(
  BuildContext context, {
  String? selected,
  bool allowNone = false,
  String noneLabel = 'Keine Kategorie',
}) {
  return showModalBottomSheet<CategoryPick>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CategoryPickerSheet(
      selected: selected,
      allowNone: allowNone,
      noneLabel: noneLabel,
    ),
  );
}

class _CategoryPickerSheet extends ConsumerWidget {
  const _CategoryPickerSheet({
    required this.selected,
    required this.allowNone,
    required this.noneLabel,
  });

  final String? selected;
  final bool allowNone;
  final String noneLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider(false));
    final theme = Theme.of(context);

    return SafeArea(
      child: categoriesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Kategorien nicht verfügbar: $e'),
        ),
        data: (categories) {
          // Every node expanded: a picker should show the whole tree at once.
          final expanded = {for (final c in categories) c.uuid};
          final visible = flattenVisible(
            buildCategoryTree(categories),
            expanded,
          );

          return ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Kategorie wählen',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (allowNone)
                ListTile(
                  leading: const Icon(Icons.block_outlined),
                  title: Text(noneLabel),
                  selected: selected == null,
                  onTap: () =>
                      Navigator.pop(context, const CategoryPick(null)),
                ),
              if (categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Noch keine Kategorien angelegt.'),
                ),
              for (final node in visible)
                ListTile(
                  contentPadding: EdgeInsets.only(
                    left: 16 + node.depth * 20,
                    right: 16,
                  ),
                  leading: Icon(
                    categoryIcon(node.category.iconName),
                    color: categoryColor(node.category.colorHex),
                  ),
                  title: Text(node.category.name),
                  selected: node.category.uuid == selected,
                  onTap: () => Navigator.pop(
                    context,
                    CategoryPick(node.category.uuid),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
