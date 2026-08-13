import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/drilldown/data/line_item.dart';
import 'package:budget_view/features/drilldown/domain/line_item_providers.dart';
import 'package:budget_view/features/drilldown/presentation/line_items_section.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rendering only, deliberately without a database: real Isar I/O never
/// completes inside `testWidgets` (see `.claude/docs/errors.md`), so the
/// repository behaviour (persistence, reorder, sums) is covered by the
/// domain tests instead. None of these scenarios drag, dismiss or tap "add",
/// so `lineItemRepositoryProvider` is never reached either. Category
/// resolution (own vs. inherited) is covered separately in
/// `line_item_category_ui_test.dart`; here `categoriesProvider(true)` is only
/// overridden with an empty list so `_CategoryBadge` has something to watch.
LineItem _item({
  required String uuid,
  String description = 'Milch',
  int amountCents = -119,
  double? quantity,
  int? unitPriceCents,
}) {
  final now = DateTime(2026, 8, 1);
  return LineItem()
    ..uuid = uuid
    ..transactionUuid = 'tx-1'
    ..description = description
    ..amountCents = amountCents
    ..quantity = quantity
    ..unitPriceCents = unitPriceCents
    ..createdAt = now
    ..updatedAt = now;
}

Transaction _transaction() {
  final now = DateTime(2026, 8, 1);
  return Transaction()
    ..uuid = 'tx-1'
    ..accountUuid = 'acc-1'
    ..amountCents = -1000
    ..bookingDate = now
    ..description = 'Supermarkt'
    ..createdAt = now
    ..updatedAt = now;
}

void main() {
  ProviderContainer containerWith(List<LineItem> items) {
    final container = ProviderContainer(
      overrides: [
        lineItemsProvider('tx-1').overrideWith((ref) => Stream.value(items)),
        categoriesProvider(true)
            .overrideWith((ref) => Stream.value(const <Category>[])),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpSection(WidgetTester tester, List<LineItem> items) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: containerWith(items),
        child: MaterialApp(
          home: Scaffold(
            body: LineItemsSection(transaction: _transaction()),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the empty state explains that there are no positions yet', (
    tester,
  ) async {
    await pumpSection(tester, const []);

    expect(find.text('Noch keine Positionen erfasst.'), findsOneWidget);
  });

  testWidgets('a subtotal is shown once there is at least one position', (
    tester,
  ) async {
    await pumpSection(tester, [_item(uuid: 'a')]);

    expect(find.text('Noch keine Positionen erfasst.'), findsNothing);
    expect(find.textContaining('Σ'), findsOneWidget);
  });

  testWidgets('each position renders its description', (tester) async {
    await pumpSection(tester, [
      _item(uuid: 'a', description: 'Milch'),
      _item(uuid: 'b', description: 'Brot'),
    ]);

    expect(find.text('Milch'), findsOneWidget);
    expect(find.text('Brot'), findsOneWidget);
  });

  testWidgets(
    'a quantity and unit price render as a "1,5 × 0,89 €" subtitle',
    (tester) async {
      await pumpSection(tester, [
        _item(
          uuid: 'a',
          description: 'Äpfel',
          quantity: 1.5,
          unitPriceCents: 89,
        ),
      ]);

      // Stops before the currency symbol on purpose: de_DE puts a
      // non-breaking space in front of the €.
      expect(find.textContaining('1,5 × 0,89'), findsOneWidget);
    },
  );

  testWidgets('each position shows a drag handle', (tester) async {
    await pumpSection(tester, [
      _item(uuid: 'a', description: 'Milch'),
      _item(uuid: 'b', description: 'Brot'),
      _item(uuid: 'c', description: 'Butter'),
    ]);

    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
  });
}
