import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category.dart';
import '../domain/category_providers.dart';
import '../domain/category_repository.dart';
import '../domain/category_tree.dart';
import '../domain/category_validation.dart';
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
              if (allowNone) ...[
                ListTile(
                  leading: const Icon(Icons.block_outlined),
                  title: Text(noneLabel),
                  selected: selected == null,
                  onTap: () =>
                      Navigator.pop(context, const CategoryPick(null)),
                ),
                // Keeps "no category" and "create one" from reading as one group.
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Neue Kategorie'),
                onTap: () => _quickCreate(context, ref),
              ),
              const Divider(height: 1),
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
                  // Its own hit area: tapping the row still selects.
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Unterkategorie in ${node.category.name}',
                    onPressed: () =>
                        _quickCreate(context, ref, parent: node.category),
                  ),
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

  /// Creates a category and returns it as the pick, so the caller that opened
  /// this sheet is left with it selected.
  Future<void> _quickCreate(
    BuildContext context,
    WidgetRef ref, {
    Category? parent,
  }) async {
    final created = await showDialog<String>(
      context: context,
      builder: (_) => _QuickCreateDialog(parent: parent),
    );
    if (created == null || !context.mounted) return;
    Navigator.pop(context, CategoryPick(created));
  }
}

/// Name only — icon, colour and order keep the entity defaults, editable later
/// in the tree screen. Offering the icon grid mid-entry would rebuild the very
/// form the user escaped by coming here.
class _QuickCreateDialog extends ConsumerStatefulWidget {
  const _QuickCreateDialog({required this.parent});

  final Category? parent;

  @override
  ConsumerState<_QuickCreateDialog> createState() => _QuickCreateDialogState();
}

class _QuickCreateDialogState extends ConsumerState<_QuickCreateDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    final invalid = CategoryValidation.name(name);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final category = Category()
        ..name = name
        ..parentUuid = widget.parent?.uuid;
      final saved = await ref.read(categoryRepositoryProvider).save(category);
      if (mounted) Navigator.pop(context, saved.uuid);
    } on CategoryInvalid catch (e) {
      // Sibling-name collisions only surface in the repository; keep the dialog
      // open with the message rather than dropping it behind the sheet.
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.parent;
    return AlertDialog(
      title: Text(
        parent == null
            ? 'Neue Kategorie'
            : 'Neue Unterkategorie in ${parent.name}',
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: 'Name', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
