import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/category/presentation/category_tree_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rendering and expand/collapse only, deliberately without a database: real
/// Isar I/O never completes inside `testWidgets` (see `.claude/docs/errors.md`),
/// so the repository behaviour is asserted in the domain tests instead.
Category _cat(
  String uuid,
  String name, {
  String? parent,
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
  ProviderContainer containerWith(List<Category> categories) {
    final container = ProviderContainer(
      overrides: [
        categoriesProvider(false).overrideWith((ref) => Stream.value(categories)),
        categoriesProvider(true).overrideWith((ref) => Stream.value(categories)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpTree(
    WidgetTester tester,
    List<Category> categories,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: containerWith(categories),
        child: const MaterialApp(home: CategoryTreeScreen()),
      ),
    );
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('roots are listed and children stay hidden until expanded', (
    tester,
  ) async {
    await pumpTree(tester, [
      _cat('a', 'Wohnen'),
      _cat('b', 'Strom', parent: 'a'),
    ]);

    expect(find.text('Wohnen'), findsOneWidget);
    expect(find.text('Strom'), findsNothing);
    expect(find.text('1 Unterkategorien'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Strom'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('siblings render ordered by sortOrder then name', (tester) async {
    await pumpTree(tester, [
      _cat('c', 'zebra', sort: 1000),
      _cat('a', 'Anfang', sort: 2000),
      _cat('b', 'Beta', sort: 1000),
    ]);

    final titles = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((label) => ['Beta', 'zebra', 'Anfang'].contains(label))
        .toList();

    expect(titles, ['Beta', 'zebra', 'Anfang']);
  });

  testWidgets('an empty tree explains what to do', (tester) async {
    await pumpTree(tester, const []);

    expect(find.text('Noch keine Kategorien. Lege eine an.'), findsOneWidget);
  });

  testWidgets('an archived category offers restore instead of a drag handle', (
    tester,
  ) async {
    await pumpTree(tester, [_cat('a', 'Alt', archived: true)]);

    expect(find.byIcon(Icons.unarchive_outlined), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
  });

  testWidgets('a leaf category shows a drag handle and no child count', (
    tester,
  ) async {
    await pumpTree(tester, [_cat('a', 'Wohnen')]);

    expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    expect(find.textContaining('Unterkategorien'), findsNothing);
  });
}
