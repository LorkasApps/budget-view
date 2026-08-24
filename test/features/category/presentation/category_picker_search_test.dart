import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/category/domain/category_repository.dart';
import 'package:budget_view/features/category/presentation/category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every saved category and hands back a fixed uuid. `implements` (not
/// `extends`) keeps the real constructor, which wants a live `Isar`, out of it.
class _RecordingCategoryRepository implements CategoryRepository {
  final List<Category> saved = [];

  @override
  Future<Category> save(Category category) async {
    category.uuid = 'new-uuid';
    saved.add(category);
    return category;
  }

  @override
  Future<void> delete(String uuid) async {}

  @override
  Future<void> restore(String uuid) async {}

  @override
  Future<void> reorderSiblings(List<Category> ordered) async {}

  @override
  Future<Category?> findByUuid(String uuid) async => null;

  @override
  Future<List<Category>> findAll({bool includeArchived = false}) async =>
      const [];

  @override
  Future<List<Category>> findChildren(String? parentUuid) async => const [];

  @override
  Future<List<Category>> findRoots() async => const [];
}

class _PickResult {
  CategoryPick? value;
  bool done = false;
}

Category _cat(String uuid, String name, {String? parent}) {
  return Category()
    ..uuid = uuid
    ..name = name
    ..parentUuid = parent;
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Three levels, because the descendant rule is only interesting below depth
  /// two: `Limonade` says nothing about the `Lebensmittel` it hangs under.
  final categories = [
    _cat('root-1', 'Lebensmittel'),
    _cat('child-1', 'Getränke', parent: 'root-1'),
    _cat('grand-1', 'Limonade', parent: 'child-1'),
    _cat('root-2', 'Freizeit'),
    _cat('child-2', 'Kino', parent: 'root-2'),
  ];

  Future<_PickResult> openPicker(
    WidgetTester tester, {
    required _RecordingCategoryRepository repository,
    bool allowNone = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final result = _PickResult();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            (ref, includeArchived) => Stream.value(categories),
          ),
          categoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                pickCategory(
                  context,
                  allowNone: allowNone,
                  noneLabel: 'Erbt von der Buchung',
                ).then((value) {
                  result.value = value;
                  result.done = true;
                });
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.byType(ElevatedButton));
    await settle(tester);

    return result;
  }

  /// The sheet's only text field while no dialog is open.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await settle(tester);
  }

  testWidgets('an empty field shows the whole tree', (tester) async {
    await openPicker(tester, repository: _RecordingCategoryRepository());

    for (final name in ['Lebensmittel', 'Getränke', 'Limonade', 'Freizeit']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('a hit pulls its whole subtree along, three levels deep', (
    tester,
  ) async {
    await openPicker(tester, repository: _RecordingCategoryRepository());
    await search(tester, 'lebensmittel');

    expect(find.text('Lebensmittel'), findsOneWidget);
    expect(find.text('Getränke'), findsOneWidget);
    expect(find.text('Limonade'), findsOneWidget);
    expect(find.text('Freizeit'), findsNothing);
    expect(find.text('Kino'), findsNothing);
  });

  testWidgets('the path to a hit is shown and stays selectable', (
    tester,
  ) async {
    final result = await openPicker(
      tester,
      repository: _RecordingCategoryRepository(),
    );
    await search(tester, 'Limonade');

    expect(find.text('Lebensmittel'), findsOneWidget, reason: 'path');
    expect(find.text('Getränke'), findsOneWidget, reason: 'path');
    expect(find.text('Freizeit'), findsNothing);

    await tester.tap(find.text('Lebensmittel'));
    await settle(tester);

    expect(result.value?.uuid, 'root-1');
  });

  testWidgets('no match leaves the create rows and says so', (tester) async {
    await openPicker(tester, repository: _RecordingCategoryRepository());
    await search(tester, 'Getranke');

    expect(find.text('Getränke'), findsNothing, reason: 'umlauts are literal');
    expect(find.text('Lebensmittel'), findsNothing);
    expect(find.text('Kein Treffer.'), findsOneWidget);
    expect(find.text('Neue Kategorie'), findsOneWidget);
  });

  testWidgets('clearing the field restores the full tree', (tester) async {
    await openPicker(tester, repository: _RecordingCategoryRepository());
    await search(tester, 'Kino');
    expect(find.text('Lebensmittel'), findsNothing);

    await tester.tap(find.byTooltip('Suche leeren'));
    await settle(tester);

    expect(find.text('Lebensmittel'), findsOneWidget);
    expect(find.text('Limonade'), findsOneWidget);
  });

  testWidgets('a filtered hit keeps the indentation of its real depth', (
    tester,
  ) async {
    await openPicker(tester, repository: _RecordingCategoryRepository());
    await search(tester, 'Lebensmittel');

    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Limonade'),
    );
    expect((tile.contentPadding! as EdgeInsets).left, 16 + 2 * 20);
  });

  testWidgets('the none option keeps its slot and wording while filtering', (
    tester,
  ) async {
    final result = await openPicker(
      tester,
      repository: _RecordingCategoryRepository(),
      allowNone: true,
    );
    await search(tester, 'Kino');

    expect(find.text('Erbt von der Buchung'), findsOneWidget);

    await tester.tap(find.text('Erbt von der Buchung'));
    await settle(tester);

    expect(result.done, isTrue);
    expect(result.value?.uuid, isNull);
  });

  testWidgets('quick-create still works while a search is active', (
    tester,
  ) async {
    final repository = _RecordingCategoryRepository();
    final result = await openPicker(tester, repository: repository);
    await search(tester, 'Lebensmittel');

    await tester.tap(find.byTooltip('Unterkategorie in Getränke'));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Limonade Bio',
    );
    await tester.tap(find.text('Anlegen'));
    await settle(tester);

    expect(repository.saved.single.parentUuid, 'child-1');
    expect(result.value?.uuid, 'new-uuid');
  });
}
