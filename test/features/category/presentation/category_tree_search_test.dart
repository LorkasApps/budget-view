import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/category/presentation/category_tree_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Search on the category tree screen: `filterCategoryTree` itself is
/// covered in `category_tree_test.dart` (domain); this file is about what
/// the screen does with the result — path visibility while starting
/// collapsed, handles/chevrons hiding, the unfiltered child count, the
/// archived toggle, and long-press still working on a filtered row.
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
  ProviderContainer containerWith(
    List<Category> categories, {
    List<Category>? whenArchivedShown,
  }) {
    final container = ProviderContainer(
      overrides: [
        categoriesProvider(false)
            .overrideWith((ref) => Stream.value(categories)),
        categoriesProvider(true).overrideWith(
          (ref) => Stream.value(whenArchivedShown ?? categories),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpTree(
    WidgetTester tester,
    List<Category> categories, {
    List<Category>? whenArchivedShown,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: containerWith(
          categories,
          whenArchivedShown: whenArchivedShown,
        ),
        child: const MaterialApp(home: CategoryTreeScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await settle(tester);
  }

  /// Rows only. The search field holds the query as text too, so asserting on
  /// a category name with `find.text` matches twice whenever the query equals
  /// that name — which is the normal case in this file.
  Finder row(String name) => find.widgetWithText(ListTile, name);

  testWidgets('a query narrows the list, a non-matching sibling vanishes', (
    tester,
  ) async {
    await pumpTree(tester, [
      _cat('a', 'Getränke'),
      _cat('b', 'Süßigkeiten'),
    ]);

    await search(tester, 'Getränke');

    expect(row('Getränke'), findsOneWidget);
    expect(row('Süßigkeiten'), findsNothing);
  });

  testWidgets('the path to a deep hit is shown though it starts collapsed', (
    tester,
  ) async {
    await pumpTree(tester, [
      _cat('parent', 'Elektronik'),
      _cat('child', 'Kopfhörer', parent: 'parent'),
    ]);

    // Collapsed by default: the child is not on screen yet.
    expect(row('Kopfhörer'), findsNothing);

    await search(tester, 'Kopfhörer');

    expect(row('Elektronik'), findsOneWidget, reason: 'path');
    expect(row('Kopfhörer'), findsOneWidget, reason: 'the hit');
  });

  testWidgets('a query hides handles, chevrons, and shows the sort hint', (
    tester,
  ) async {
    await pumpTree(tester, [
      _cat('parent', 'Elektronik'),
      _cat('child', 'Kopfhörer', parent: 'parent'),
    ]);

    await search(tester, 'Elektronik');

    expect(find.text('Sortieren erst ohne Suche'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('clearing the query brings handles back and re-collapses', (
    tester,
  ) async {
    await pumpTree(tester, [
      _cat('parent', 'Elektronik'),
      _cat('child', 'Kopfhörer', parent: 'parent'),
    ]);

    await search(tester, 'Kopfhörer');
    expect(row('Kopfhörer'), findsOneWidget);

    await tester.tap(find.byTooltip('Suche leeren'));
    await settle(tester);

    expect(find.text('Sortieren erst ohne Suche'), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    expect(row('Elektronik'), findsOneWidget);
    // Collapsed again: the query never touched `_expanded`.
    expect(row('Kopfhörer'), findsNothing);
  });

  testWidgets('umlauts stay literal, like the picker (038)', (tester) async {
    await pumpTree(tester, [_cat('a', 'Brühe')]);

    await search(tester, 'Bruehe');
    expect(row('Brühe'), findsNothing, reason: 'umlauts are literal');
    expect(find.text('Kein Treffer.'), findsOneWidget);

    await search(tester, 'brühe');
    expect(row('Brühe'), findsOneWidget, reason: 'case-insensitive');
  });

  testWidgets('the child count stays the unfiltered total under a query', (
    tester,
  ) async {
    await pumpTree(tester, [
      _cat('parent', 'Haushalt'),
      _cat('c1', 'Strom', parent: 'parent'),
      _cat('c2', 'Wasser', parent: 'parent'),
      _cat('c3', 'Gas', parent: 'parent'),
    ]);

    // Only the child matches; the parent is kept solely as its path, and
    // `filterCategoryTree` prunes its other two children away.
    await search(tester, 'Strom');

    expect(row('Haushalt'), findsOneWidget, reason: 'path');
    expect(row('Strom'), findsOneWidget);
    expect(row('Wasser'), findsNothing);
    expect(row('Gas'), findsNothing);
    // The subtitle counts off the unfiltered list, not `node.children`.
    expect(find.text('3 Unterkategorien'), findsOneWidget);
  });

  testWidgets('the archived toggle still governs what search can surface', (
    tester,
  ) async {
    await pumpTree(
      tester,
      [_cat('a', 'Aktiv')],
      whenArchivedShown: [_cat('a', 'Aktiv'), _cat('b', 'Alt', archived: true)],
    );

    await search(tester, 'Alt');
    expect(row('Alt'), findsNothing);
    expect(find.text('Kein Treffer.'), findsOneWidget);

    await tester.tap(find.byTooltip('Archivierte anzeigen'));
    await settle(tester);

    expect(row('Alt'), findsOneWidget);
  });

  testWidgets('long-press on a filtered childless row offers to archive', (
    tester,
  ) async {
    await pumpTree(tester, [_cat('a', 'Freizeit')]);

    await search(tester, 'Freizeit');
    await tester.longPress(row('Freizeit'));
    await settle(tester);

    expect(find.text('Kategorie archivieren?'), findsOneWidget);
  });

  testWidgets('long-press on a filtered row with children refuses', (
    tester,
  ) async {
    await pumpTree(tester, [
      _cat('parent', 'Technik'),
      _cat('c1', 'Kabel', parent: 'parent'),
      _cat('c2', 'Stecker', parent: 'parent'),
    ]);

    // The query matches the parent itself, so it is on screen directly.
    await search(tester, 'Technik');
    await tester.longPress(row('Technik'));
    await settle(tester);

    expect(
      find.text(
        'Kategorie hat 2 Unterkategorien — bitte zuerst verschieben.',
      ),
      findsOneWidget,
    );
    expect(find.text('Kategorie archivieren?'), findsNothing);
  });

  testWidgets('a query matching nothing shows the no-results message', (
    tester,
  ) async {
    await pumpTree(tester, [_cat('a', 'Freizeit')]);

    await search(tester, 'zzz-nichts-passt');

    expect(find.text('Kein Treffer.'), findsOneWidget);
  });
}
