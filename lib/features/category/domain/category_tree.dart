// Only `immutable`: foundation also exports a `Category` annotation, which
// would collide with the entity of the same name.
import 'package:flutter/foundation.dart' show immutable;

import '../data/category.dart';

/// One category plus its children, at a known depth.
@immutable
class CategoryNode {
  const CategoryNode({
    required this.category,
    required this.children,
    required this.depth,
  });

  final Category category;
  final List<CategoryNode> children;
  final int depth;

  bool get hasChildren => children.isNotEmpty;
}

/// Groups a flat category list into roots and children.
///
/// Siblings are ordered by `sortOrder` then `name`. A category whose parent is
/// null, or absent from [categories], is a root — so filtering archived parents
/// out never makes their children disappear.
List<CategoryNode> buildCategoryTree(List<Category> categories) {
  final known = {for (final category in categories) category.uuid};
  final childrenOf = <String?, List<Category>>{};

  for (final category in categories) {
    final declared = category.parentUuid;
    final parent = declared != null && known.contains(declared) ? declared : null;
    childrenOf.putIfAbsent(parent, () => <Category>[]).add(category);
  }

  List<CategoryNode> build(String? parentUuid, int depth) {
    final children = childrenOf[parentUuid] ?? const <Category>[];
    final ordered = [...children]..sort(_bySortOrderThenName);
    return [
      for (final category in ordered)
        CategoryNode(
          category: category,
          children: build(category.uuid, depth + 1),
          depth: depth,
        ),
    ];
  }

  return build(null, 0);
}

/// Depth-first list of the nodes currently on screen: a node's children are
/// included only while its uuid is in [expanded].
List<CategoryNode> flattenVisible(
  List<CategoryNode> roots,
  Set<String> expanded,
) {
  final visible = <CategoryNode>[];

  void walk(List<CategoryNode> nodes) {
    for (final node in nodes) {
      visible.add(node);
      if (expanded.contains(node.category.uuid)) walk(node.children);
    }
  }

  walk(roots);
  return visible;
}

/// Prunes the tree to what a search shows: a node whose name contains [query]
/// keeps its whole subtree, and the path down to such a node is kept too, so a
/// hit deep in the tree still reads as belonging where it belongs.
///
/// Matching is case-insensitive substring and otherwise literal — `Bruehe` does
/// not find `Brühe`. `normalizeForMatching` is deliberately not used: it exists
/// for machine comparison in dedupe and tagging, and widening it later would
/// silently change what search does.
List<CategoryNode> filterCategoryTree(List<CategoryNode> roots, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return roots;

  List<CategoryNode> prune(List<CategoryNode> nodes) {
    final kept = <CategoryNode>[];
    for (final node in nodes) {
      if (node.category.name.toLowerCase().contains(needle)) {
        kept.add(node);
        continue;
      }
      final children = prune(node.children);
      if (children.isNotEmpty) {
        kept.add(
          CategoryNode(
            category: node.category,
            children: children,
            depth: node.depth,
          ),
        );
      }
    }
    return kept;
  }

  return prune(roots);
}

/// [rootUuid] plus every uuid below it. Empty [rootUuid] yields nothing.
Set<String> subtreeUuids(List<Category> categories, String rootUuid) {
  if (rootUuid.isEmpty) return const {};

  final inside = {rootUuid};
  var grew = true;
  while (grew) {
    grew = false;
    for (final candidate in categories) {
      if (inside.contains(candidate.uuid)) continue;
      if (inside.contains(candidate.parentUuid)) {
        inside.add(candidate.uuid);
        grew = true;
      }
    }
  }
  return inside;
}

/// Uuids that may not become [category]'s parent: itself and its descendants.
Set<String> ineligibleParents(List<Category> categories, Category category) =>
    subtreeUuids(categories, category.uuid);

int _bySortOrderThenName(Category a, Category b) {
  final bySortOrder = a.sortOrder.compareTo(b.sortOrder);
  if (bySortOrder != 0) return bySortOrder;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
