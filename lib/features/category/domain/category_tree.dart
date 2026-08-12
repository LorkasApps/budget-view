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

/// Uuids that may not become [category]'s parent: itself and its descendants.
Set<String> ineligibleParents(List<Category> categories, Category category) {
  if (category.uuid.isEmpty) return const {};

  final blocked = {category.uuid};
  var grew = true;
  while (grew) {
    grew = false;
    for (final candidate in categories) {
      if (blocked.contains(candidate.uuid)) continue;
      if (blocked.contains(candidate.parentUuid)) {
        blocked.add(candidate.uuid);
        grew = true;
      }
    }
  }
  return blocked;
}

int _bySortOrderThenName(Category a, Category b) {
  final bySortOrder = a.sortOrder.compareTo(b.sortOrder);
  if (bySortOrder != 0) return bySortOrder;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
