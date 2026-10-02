import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/category/presentation/category_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Future<void> openForm(
    WidgetTester tester, {
    required List<Category> categories,
    Category? existing,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            (ref, includeArchived) => Stream.value(categories),
          ),
        ],
        child: MaterialApp(home: CategoryFormScreen(existing: existing)),
      ),
    );
    await settle(tester);
  }

  /// `items` is not a public field on `DropdownButtonFormField`, so the offered
  /// options are read the way a user sees them: a closed dropdown renders only
  /// its current selection, so anything found after this tap was in the menu.
  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await settle(tester);
  }

  DropdownButtonFormField<String?> parentField(WidgetTester tester) {
    return tester.widget<DropdownButtonFormField<String?>>(
      find.byType(DropdownButtonFormField<String?>),
    );
  }

  testWidgets('the parent dropdown offers roots only', (tester) async {
    await openForm(
      tester,
      categories: [
        _cat('root-1', 'Lebensmittel'),
        _cat('child-1', 'Getränke', parent: 'root-1'),
        _cat('root-2', 'Freizeit'),
      ],
    );
    await openMenu(tester);

    expect(find.text('Lebensmittel'), findsOneWidget);
    expect(find.text('Freizeit'), findsOneWidget);
    expect(find.text('Getränke'), findsNothing);
  });

  testWidgets('a child promoted by an absent parent is not offered', (
    tester,
  ) async {
    await openForm(
      tester,
      categories: [
        _cat('root-1', 'Lebensmittel'),
        _cat('child-x', 'Strom', parent: 'archived-root'),
      ],
    );
    await openMenu(tester);

    // It renders at root level in the tree, but its stored parentUuid makes it
    // a child — taking it as a parent would mean three levels in the data.
    expect(find.text('Lebensmittel'), findsOneWidget);
    expect(find.text('Strom'), findsNothing);
  });

  testWidgets('a category is not offered as its own parent', (tester) async {
    final existing = _cat('root-1', 'Lebensmittel');
    await openForm(
      tester,
      categories: [existing, _cat('root-2', 'Freizeit')],
      existing: existing,
    );
    await openMenu(tester);

    expect(find.text('Freizeit'), findsOneWidget, reason: 'the other root');
    // Exactly one occurrence, and it is the name field holding the category's
    // own name — the menu does not offer it a second time.
    expect(find.text('Lebensmittel'), findsOneWidget);
  });

  testWidgets('a category with children has a disabled field and a reason', (
    tester,
  ) async {
    final existing = _cat('root-1', 'Lebensmittel');
    await openForm(
      tester,
      categories: [
        existing,
        _cat('child-1', 'Getränke', parent: 'root-1'),
        _cat('root-2', 'Freizeit'),
      ],
      existing: existing,
    );

    expect(parentField(tester).onChanged, isNull);
    expect(
      find.text('Hat Unterkategorien — kann selbst keine werden'),
      findsOneWidget,
    );
  });

  testWidgets('a childless category keeps the field enabled', (tester) async {
    final existing = _cat('root-1', 'Lebensmittel');
    await openForm(
      tester,
      categories: [existing, _cat('root-2', 'Freizeit')],
      existing: existing,
    );

    expect(parentField(tester).onChanged, isNotNull);
    expect(
      find.text('Hat Unterkategorien — kann selbst keine werden'),
      findsNothing,
    );
  });
}
