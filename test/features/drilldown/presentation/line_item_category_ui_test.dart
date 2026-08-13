import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/drilldown/data/line_item.dart';
import 'package:budget_view/features/drilldown/domain/line_item_providers.dart';
import 'package:budget_view/features/drilldown/presentation/line_item_edit_sheet.dart';
import 'package:budget_view/features/drilldown/presentation/line_items_section.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fractal category inheritance in the UI, deliberately without a database:
/// real Isar I/O never completes inside `testWidgets` (see
/// `.claude/docs/errors.md`). No scenario here fills out and submits the
/// sheet, so `lineItemRepositoryProvider` is never reached.
Category _cat(String uuid, String name) => Category()
  ..uuid = uuid
  ..name = name;

LineItem _item({required String uuid, String? categoryUuid}) {
  final now = DateTime(2026, 8, 1);
  return LineItem()
    ..uuid = uuid
    ..transactionUuid = 'tx-1'
    ..description = 'Position'
    ..amountCents = -100
    ..categoryUuid = categoryUuid
    ..createdAt = now
    ..updatedAt = now;
}

Transaction _transaction({String? categoryUuid}) {
  final now = DateTime(2026, 8, 1);
  return Transaction()
    ..uuid = 'tx-1'
    ..accountUuid = 'acc-1'
    ..categoryUuid = categoryUuid
    ..amountCents = -1000
    ..bookingDate = now
    ..description = 'Supermarkt'
    ..createdAt = now
    ..updatedAt = now;
}

// A fixed pair of categories shared by every scenario below.
final _lebensmittel = _cat('cat-a', 'Lebensmittel');
final _getraenke = _cat('cat-b', 'Getränke');

void main() {
  ProviderContainer buildContainer({
    required List<LineItem> items,
    List<Category> categories = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        lineItemsProvider('tx-1').overrideWith((ref) => Stream.value(items)),
        categoriesProvider(true)
            .overrideWith((ref) => Stream.value(categories)),
        categoriesProvider(false)
            .overrideWith((ref) => Stream.value(categories)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpSection(
    WidgetTester tester, {
    required Transaction transaction,
    required List<LineItem> items,
    List<Category> categories = const [],
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: buildContainer(items: items, categories: categories),
        child: MaterialApp(
          home: Scaffold(body: LineItemsSection(transaction: transaction)),
        ),
      ),
    );
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    "a position's own category wins and shows no inherit arrow",
    (tester) async {
      await pumpSection(
        tester,
        transaction: _transaction(categoryUuid: _getraenke.uuid),
        items: [_item(uuid: 'a', categoryUuid: _lebensmittel.uuid)],
        categories: [_lebensmittel, _getraenke],
      );

      expect(find.text('Lebensmittel'), findsOneWidget);
      expect(find.text('Getränke'), findsNothing);
      expect(find.byIcon(Icons.subdirectory_arrow_right), findsNothing);
    },
  );

  testWidgets(
    'a null position category inherits and shows the parent\'s name with '
    'the inherit arrow',
    (tester) async {
      await pumpSection(
        tester,
        transaction: _transaction(categoryUuid: _getraenke.uuid),
        items: [_item(uuid: 'a')],
        categories: [_lebensmittel, _getraenke],
      );

      expect(find.text('Getränke'), findsOneWidget);
      expect(find.byIcon(Icons.subdirectory_arrow_right), findsOneWidget);
    },
  );

  testWidgets(
    'a null position category with an uncategorized parent shows the "no '
    'category" placeholder',
    (tester) async {
      await pumpSection(
        tester,
        transaction: _transaction(),
        items: [_item(uuid: 'a')],
        categories: [_lebensmittel, _getraenke],
      );

      expect(find.text('—'), findsOneWidget);
      expect(find.byIcon(Icons.subdirectory_arrow_right), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the category row opens a picker offering the resolved parent '
    "category as the inherit option's label",
    (tester) async {
      final parent = _transaction(categoryUuid: _getraenke.uuid);

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: buildContainer(
            items: const [],
            categories: [_lebensmittel, _getraenke],
          ),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showLineItemSheet(context, parent: parent),
                  child: const Text('Position hinzufügen'),
                ),
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Position hinzufügen'));
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Kategorie'));
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Kategorie wählen'), findsOneWidget);
      expect(
        find.text('Erbt von der Buchung (Getränke)'),
        findsAtLeastNWidgets(1),
      );
    },
  );
}
