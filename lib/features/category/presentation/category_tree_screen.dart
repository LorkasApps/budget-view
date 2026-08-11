import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category.dart';
import '../domain/category_providers.dart';
import '../domain/category_repository.dart';
import '../domain/category_tree.dart';
import 'category_form_screen.dart';
import 'category_style.dart';

/// The category tree: expand, reorder within a level, edit, archive, restore.
class CategoryTreeScreen extends ConsumerStatefulWidget {
  const CategoryTreeScreen({super.key});

  @override
  ConsumerState<CategoryTreeScreen> createState() => _CategoryTreeScreenState();
}

class _CategoryTreeScreenState extends ConsumerState<CategoryTreeScreen> {
  bool _showArchived = false;
  final Set<String> _expanded = <String>{};

  void _openForm({Category? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryFormScreen(existing: existing),
      ),
    );
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _delete(CategoryNode node) async {
    // Children are already known here, so refuse before asking rather than
    // asking and then refusing. The repository still guards the real rule,
    // including archived children that this list may be hiding.
    if (node.hasChildren) {
      _notify(
        'Kategorie hat ${node.children.length} Unterkategorien '
        '— bitte zuerst verschieben.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kategorie archivieren?'),
        content: Text('"${node.category.name}" wird archiviert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archivieren'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(categoryRepositoryProvider).delete(node.category.uuid);
    } on CategoryDeleteBlocked catch (error) {
      if (mounted) _notify(error.message);
    }
  }

  Future<void> _reorder(
    List<CategoryNode> visible,
    int oldIndex,
    int newIndex,
  ) async {
    // onReorderItem already accounts for the removed item, so newIndex needs
    // no adjustment here.
    final moved = visible[oldIndex].category;
    final destination = visible[newIndex].category;

    if (destination.parentUuid != moved.parentUuid) {
      _notify('Nur innerhalb derselben Ebene sortierbar');
      return;
    }

    final siblings = visible
        .map((node) => node.category)
        .where((category) => category.parentUuid == moved.parentUuid)
        .toList();
    final from = siblings.indexWhere((c) => c.uuid == moved.uuid);
    final to = siblings.indexWhere((c) => c.uuid == destination.uuid);
    if (from == -1 || to == -1) return;

    final ordered = [...siblings]..removeAt(from);
    ordered.insert(to, moved);
    await ref.read(categoryRepositoryProvider).reorderSiblings(ordered);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider(_showArchived));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategorien'),
        actions: [
          IconButton(
            tooltip: _showArchived
                ? 'Archivierte ausblenden'
                : 'Archivierte anzeigen',
            icon: Icon(
              _showArchived ? Icons.visibility_off : Icons.archive_outlined,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Text('Noch keine Kategorien. Lege eine an.'),
            );
          }

          final visible = flattenVisible(
            buildCategoryTree(categories),
            _expanded,
          );

          return ReorderableListView.builder(
            // Default drag handles hijack long-press, which archives here.
            buildDefaultDragHandles: false,
            itemCount: visible.length,
            onReorderItem: (oldIndex, newIndex) =>
                _reorder(visible, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final node = visible[index];
              return _CategoryRow(
                key: ValueKey(node.category.uuid),
                node: node,
                index: index,
                expanded: _expanded.contains(node.category.uuid),
                onToggleExpanded: () => setState(() {
                  final uuid = node.category.uuid;
                  if (!_expanded.remove(uuid)) _expanded.add(uuid);
                }),
                onEdit: () => _openForm(existing: node.category),
                onDelete: () => _delete(node),
                onRestore: () => ref
                    .read(categoryRepositoryProvider)
                    .restore(node.category.uuid),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.node,
    required this.index,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final CategoryNode node;
  final int index;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = node.category;

    return Padding(
      padding: EdgeInsets.only(left: node.depth * 20),
      child: ListTile(
        leading: node.hasChildren
            ? IconButton(
                tooltip: expanded ? 'Einklappen' : 'Ausklappen',
                icon: Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                ),
                onPressed: onToggleExpanded,
              )
            : const SizedBox(width: 40),
        title: Row(
          children: [
            Icon(
              categoryIcon(category.iconName),
              color: categoryColor(category.colorHex),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                overflow: TextOverflow.ellipsis,
                style: category.archived
                    ? theme.textTheme.bodyLarge?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: theme.disabledColor,
                      )
                    : null,
              ),
            ),
          ],
        ),
        subtitle: node.hasChildren
            ? Text(
                '${node.children.length} Unterkategorien',
                style: theme.textTheme.bodySmall,
              )
            : null,
        trailing: category.archived
            ? IconButton(
                tooltip: 'Wiederherstellen',
                icon: const Icon(Icons.unarchive_outlined),
                onPressed: onRestore,
              )
            : ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
        onTap: onEdit,
        onLongPress: category.archived ? null : onDelete,
      ),
    );
  }
}
