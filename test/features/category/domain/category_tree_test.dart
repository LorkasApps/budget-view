import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_tree.dart';
import 'package:flutter_test/flutter_test.dart';

Category _cat(
  String uuid,
  String name, {
  String parent = '',
  int sort = 1000,
  bool archived = false,
}) {
  return Category()
    ..uuid = uuid
    ..name = name
    ..parentUuid = parent
    ..sortOrder = sort
    ..archived = archived;
}

void main() {
  test('nests children under their parent and tracks depth', () {
    final tree = buildCategoryTree([
      _cat('a', 'Wohnen'),
      _cat('b', 'Strom', parent: 'a'),
      _cat('c', 'Grundgebühr', parent: 'b'),
    ]);

    expect(tree.length, 1);
    expect(tree.single.depth, 0);
    expect(tree.single.children.single.category.uuid, 'b');
    expect(tree.single.children.single.depth, 1);
    expect(tree.single.children.single.children.single.depth, 2);
  });

  test('orders siblings by sortOrder, then by name case-insensitively', () {
    final tree = buildCategoryTree([
      _cat('c', 'zebra', sort: 1000),
      _cat('a', 'Anfang', sort: 2000),
      _cat('b', 'Beta', sort: 1000),
    ]);

    expect(tree.map((node) => node.category.uuid), ['b', 'c', 'a']);
  });

  test('promotes a category whose parent is missing to a root', () {
    final tree = buildCategoryTree([
      _cat('orphan', 'Waise', parent: 'archived-parent'),
    ]);

    expect(tree.single.category.uuid, 'orphan');
    expect(tree.single.depth, 0);
  });

  test('flattenVisible only descends into expanded nodes', () {
    final tree = buildCategoryTree([
      _cat('a', 'Wohnen'),
      _cat('b', 'Strom', parent: 'a'),
      _cat('c', 'Mobilität'),
    ]);

    // Equal sortOrder, so the name tiebreak puts Mobilität ahead of Wohnen.
    expect(
      flattenVisible(tree, const <String>{}).map((n) => n.category.uuid),
      ['c', 'a'],
    );
    expect(
      flattenVisible(tree, {'a'}).map((n) => n.category.uuid),
      ['c', 'a', 'b'],
    );
  });

  test('ineligibleParents covers the category itself and its descendants', () {
    final categories = [
      _cat('a', 'Wohnen'),
      _cat('b', 'Strom', parent: 'a'),
      _cat('c', 'Grundgebühr', parent: 'b'),
      _cat('d', 'Mobilität'),
    ];

    final blocked = ineligibleParents(categories, categories.first);

    expect(blocked, {'a', 'b', 'c'});
    expect(blocked.contains('d'), isFalse);
  });

  test('ineligibleParents is empty for an unsaved category', () {
    final blocked = ineligibleParents([_cat('a', 'Wohnen')], Category());

    expect(blocked, isEmpty);
  });
}
