import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/category/domain/category_repository.dart';
import 'package:budget_view/features/category/presentation/category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every saved category and hands back a fixed uuid, mirroring what
/// the real `save` returns. `implements` (not `extends`) means the real
/// constructor, which wants a live `Isar`, `SyncAdapter` and
/// `TransactionRepository`, is never called.
class _RecordingCategoryRepository implements CategoryRepository {
  final List<Category> saved = [];
  bool rejectSave = false;

  @override
  Future<Category> save(Category category) async {
    if (rejectSave) {
      throw const CategoryInvalid('Name bereits vergeben');
    }
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

/// Tracks a `pickCategory` call across the async gap so a test can assert
/// both whether it has returned yet and what it returned.
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

  Future<_PickResult> openPicker(
    WidgetTester tester, {
    required List<Category> categories,
    required _RecordingCategoryRepository repository,
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
                pickCategory(context).then((value) {
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

  final categories = [
    _cat('root-1', 'Lebensmittel'),
    _cat('child-1', 'Getränke', parent: 'root-1'),
    _cat('root-2', 'Freizeit'),
  ];

  testWidgets('the sheet offers a root create row and a per-row add button', (
    tester,
  ) async {
    await openPicker(
      tester,
      categories: categories,
      repository: _RecordingCategoryRepository(),
    );

    expect(find.text('Neue Kategorie'), findsOneWidget);
    expect(find.byTooltip('Unterkategorie in Lebensmittel'), findsOneWidget);
    expect(find.byTooltip('Unterkategorie in Getränke'), findsOneWidget);
    expect(find.byTooltip('Unterkategorie in Freizeit'), findsOneWidget);
  });

  testWidgets(
    'a row add button quick-creates a child and returns it as the pick',
    (tester) async {
      final repository = _RecordingCategoryRepository();
      final result = await openPicker(
        tester,
        categories: categories,
        repository: repository,
      );

      await tester.tap(find.byTooltip('Unterkategorie in Lebensmittel'));
      await settle(tester);

      expect(find.text('Neue Unterkategorie in Lebensmittel'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Bio');
      await tester.tap(find.text('Anlegen'));
      await settle(tester);

      expect(repository.saved, hasLength(1));
      expect(repository.saved.single.name, 'Bio');
      expect(repository.saved.single.parentUuid, 'root-1');
      expect(result.done, isTrue);
      // No value equality on CategoryPick, so compare the field.
      expect(result.value?.uuid, 'new-uuid');
    },
  );

  testWidgets(
    'the root create row quick-creates a category without a parent',
    (tester) async {
      final repository = _RecordingCategoryRepository();
      await openPicker(
        tester,
        categories: categories,
        repository: repository,
      );

      await tester.tap(find.widgetWithText(ListTile, 'Neue Kategorie'));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'Sonstiges');
      await tester.tap(find.text('Anlegen'));
      await settle(tester);

      expect(repository.saved, hasLength(1));
      expect(repository.saved.single.parentUuid, isNull);
    },
  );

  testWidgets(
    'a rejected save keeps the dialog open with the message and no pick',
    (tester) async {
      final repository = _RecordingCategoryRepository()..rejectSave = true;
      final result = await openPicker(
        tester,
        categories: categories,
        repository: repository,
      );

      await tester.tap(find.byTooltip('Unterkategorie in Lebensmittel'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Bio');
      await tester.tap(find.text('Anlegen'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Name bereits vergeben'), findsOneWidget);
      expect(repository.saved, isEmpty);
      expect(result.done, isFalse);
    },
  );

  testWidgets('an empty name is rejected before the repository is asked', (
    tester,
  ) async {
    final repository = _RecordingCategoryRepository();
    final result = await openPicker(
      tester,
      categories: categories,
      repository: repository,
    );

    await tester.tap(find.byTooltip('Unterkategorie in Lebensmittel'));
    await settle(tester);
    await tester.tap(find.text('Anlegen'));
    await settle(tester);

    expect(find.text('Name erforderlich'), findsOneWidget);
    expect(repository.saved, isEmpty);
    expect(result.done, isFalse);
  });

  testWidgets('tapping a row selects it and does not quick-create', (
    tester,
  ) async {
    final repository = _RecordingCategoryRepository();
    final result = await openPicker(
      tester,
      categories: categories,
      repository: repository,
    );

    await tester.tap(find.text('Lebensmittel'));
    await settle(tester);

    expect(result.done, isTrue);
    expect(result.value?.uuid, 'root-1');
    expect(repository.saved, isEmpty);
  });
}
