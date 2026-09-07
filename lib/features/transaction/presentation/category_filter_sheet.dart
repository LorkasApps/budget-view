import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../category/domain/category_providers.dart';
import '../../category/domain/category_tree.dart';
import '../../category/presentation/category_style.dart';
import '../domain/transaction_filter.dart';

/// Lets the user pick which categories the booking list shows.
///
/// Deliberately not `pickCategory`: that sheet carries quick-create, and
/// creating a category while narrowing a list is a different intent. Here all
/// three states — every category, none, or one including its children — are
/// rows of the same list, so the neutral option is visible rather than hidden
/// behind a clear button.
///
/// Returns `null` when dismissed.
Future<CategoryFilter?> pickCategoryFilter(
  BuildContext context, {
  required CategoryFilter selected,
}) {
  return showModalBottomSheet<CategoryFilter>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CategoryFilterSheet(selected: selected),
  );
}

class _CategoryFilterSheet extends ConsumerWidget {
  const _CategoryFilterSheet({required this.selected});

  final CategoryFilter selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Archived categories stay out, the same offer the picker makes: a filter
    // for something the user cannot pick by hand elsewhere is a dead end.
    final categoriesAsync = ref.watch(categoriesProvider(false));

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Kategorie filtern', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          Flexible(
            child: categoriesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Fehler: $e'),
              ),
              data: (categories) {
                final roots = buildCategoryTree(categories);
                final expanded = {for (final c in categories) c.uuid};
                final rows = flattenVisible(roots, expanded);

                return ListView(
                  shrinkWrap: true,
                  children: [
                    _OptionTile(
                      label: 'Alle Kategorien',
                      icon: Icons.clear_all,
                      isSelected: selected.mode == CategoryFilterMode.all,
                      onTap: () => Navigator.pop(
                        context,
                        const CategoryFilter.all(),
                      ),
                    ),
                    _OptionTile(
                      label: 'Ohne Kategorie',
                      icon: Icons.label_off_outlined,
                      isSelected: selected.mode == CategoryFilterMode.without,
                      onTap: () => Navigator.pop(
                        context,
                        const CategoryFilter.without(),
                      ),
                    ),
                    const Divider(height: 1),
                    for (final node in rows)
                      _OptionTile(
                        label: node.category.name,
                        icon: categoryIcon(node.category.iconName),
                        iconColor: categoryColor(node.category.colorHex),
                        depth: node.depth,
                        isSelected: selected.rootUuid == node.category.uuid,
                        subtitle: node.hasChildren
                            ? 'mit Unterkategorien'
                            : null,
                        onTap: () => Navigator.pop(
                          context,
                          CategoryFilter.subtree(
                            rootUuid: node.category.uuid,
                            uuids: subtreeUuids(categories, node.category.uuid),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
    this.subtitle,
    this.depth = 0,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? iconColor;
  final String? subtitle;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: 16 + depth * 16.0, right: 16),
      leading: Icon(icon, color: iconColor),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: isSelected ? const Icon(Icons.check) : null,
      selected: isSelected,
      onTap: onTap,
    );
  }
}
