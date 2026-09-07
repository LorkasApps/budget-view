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
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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

  /// [childCount] comes from the unfiltered list, not from `node.children`,
  /// which a search prunes — the refusal must state the real number.
  Future<void> _delete(CategoryNode node, int childCount) async {
    // Children are already known here, so refuse before asking rather than
    // asking and then refusing. The repository still guards the real rule,
    // including archived children that this list may be hiding.
    if (childCount > 0) {
      _notify(
        'Kategorie hat $childCount Unterkategorien '
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
    final theme = Theme.of(context);
    final query = _search.text;
    final searching = query.trim().isNotEmpty;

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: 'Suchen',
                border: const OutlineInputBorder(),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Suche leeren',
                        onPressed: () => setState(_search.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Text(
                    'Sortieren erst ohne Suche',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          Expanded(
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (categories) {
                if (categories.isEmpty) {
                  return const Center(
                    child: Text('Noch keine Kategorien. Lege eine an.'),
                  );
                }

                final roots = buildCategoryTree(categories);
                // Every node expanded while searching: `filterCategoryTree`
                // keeps the path down to a hit, and a collapsed path is a path
                // nobody can see.
                final visible = flattenVisible(
                  searching ? filterCategoryTree(roots, query) : roots,
                  searching
                      ? {for (final c in categories) c.uuid}
                      : _expanded,
                );
                if (visible.isEmpty) {
                  return const Center(child: Text('Kein Treffer.'));
                }

                // Counted off the unfiltered list: a search prunes a path
                // node's children, and a subtitle that shrinks with a query
                // reads as if children had been archived or lost.
                final childCounts = <String, int>{};
                for (final category in categories) {
                  final parent = category.parentUuid;
                  if (parent == null) continue;
                  childCounts[parent] = (childCounts[parent] ?? 0) + 1;
                }

                Widget rowAt(int index) {
                  final node = visible[index];
                  final childCount = childCounts[node.category.uuid] ?? 0;
                  return _CategoryRow(
                    key: ValueKey(node.category.uuid),
                    node: node,
                    index: index,
                    childCount: childCount,
                    searching: searching,
                    expanded: _expanded.contains(node.category.uuid),
                    onToggleExpanded: () => setState(() {
                      final uuid = node.category.uuid;
                      if (!_expanded.remove(uuid)) _expanded.add(uuid);
                    }),
                    onEdit: () => _openForm(existing: node.category),
                    onDelete: () => _delete(node, childCount),
                    onRestore: () => ref
                        .read(categoryRepositoryProvider)
                        .restore(node.category.uuid),
                  );
                }

                // A plain list while searching rather than a reorderable one
                // with hidden handles: `ReorderableListView` also offers
                // reorder through semantics actions, so hiding the handle
                // alone would leave sorting reachable on a filtered list.
                if (searching) {
                  return ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, index) => rowAt(index),
                  );
                }

                return ReorderableListView.builder(
                  // Default handles hijack long-press, which archives here.
                  buildDefaultDragHandles: false,
                  itemCount: visible.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      _reorder(visible, oldIndex, newIndex),
                  itemBuilder: (context, index) => rowAt(index),
                );
              },
            ),
          ),
        ],
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
    required this.childCount,
    required this.searching,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final CategoryNode node;
  final int index;
  final int childCount;
  final bool searching;
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
        // No chevron while searching: everything is expanded already, so a
        // toggle would be a control that visibly does nothing.
        leading: !searching && node.hasChildren
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
        subtitle: childCount > 0
            ? Text(
                '$childCount Unterkategorien',
                style: theme.textTheme.bodySmall,
              )
            : null,
        trailing: category.archived
            ? IconButton(
                tooltip: 'Wiederherstellen',
                icon: const Icon(Icons.unarchive_outlined),
                onPressed: onRestore,
              )
            : searching
                ? null
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
