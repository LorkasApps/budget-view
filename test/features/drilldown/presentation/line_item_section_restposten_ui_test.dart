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

/// Rendering only, deliberately without a database: real Isar I/O never
/// completes inside `testWidgets` (see `.claude/docs/errors.md`). No scenario
/// here drags, dismisses or saves, so neither `lineItemRepositoryProvider`
/// nor `restpostenReconcilerProvider` is ever reached. Covers how the
/// auto-managed Restposten row renders differently from a regular position —
/// gap math is covered by `restposten_reconciler_test.dart`, guard rules by
/// `line_item_repository_restposten_guard_test.dart`.
///
/// The managed row's own description is deliberately `Pfandflasche`, never
/// the default `Restposten`, so `find.text('Restposten')` can only ever match
/// the badge.
LineItem _item({
  required String uuid,
  String description = 'Milch',
  int amountCents = -119,
  LineItemKind kind = LineItemKind.regular,
}) {
  final now = DateTime(2026, 8, 1);
  return LineItem()
    ..uuid = uuid
    ..transactionUuid = 'tx-1'
    ..description = description
    ..amountCents = amountCents
    ..kind = kind
    ..createdAt = now
    ..updatedAt = now;
}

Transaction _transaction({int amountCents = -5000}) {
  final now = DateTime(2026, 8, 1);
  return Transaction()
    ..uuid = 'tx-1'
    ..accountUuid = 'acc-1'
    ..amountCents = amountCents
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

  Future<void> pumpSection(
    WidgetTester tester,
    List<LineItem> items, {
    int parentAmountCents = -5000,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: containerWith(items),
        child: MaterialApp(
          home: Scaffold(
            body: LineItemsSection(
              transaction: _transaction(amountCents: parentAmountCents),
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('the managed row shows a "Restposten" badge', (tester) async {
    await pumpSection(tester, [
      _item(uuid: 'a', description: 'Milch', amountCents: -3000),
      _item(
        uuid: 'b',
        description: 'Pfandflasche',
        amountCents: -2000,
        kind: LineItemKind.restposten,
      ),
    ]);

    expect(find.text('Restposten'), findsOneWidget);
  });

  testWidgets(
    'only the regular row shows a drag handle, not the managed one',
    (tester) async {
      await pumpSection(tester, [
        _item(uuid: 'a', description: 'Milch', amountCents: -3000),
        _item(
          uuid: 'b',
          description: 'Pfandflasche',
          amountCents: -2000,
          kind: LineItemKind.restposten,
        ),
      ]);

      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    },
  );

  testWidgets(
    'only the regular row is wrapped in a Dismissible, not the managed one',
    (tester) async {
      await pumpSection(tester, [
        _item(uuid: 'a', description: 'Milch', amountCents: -3000),
        _item(uuid: 'b', description: 'Brot', amountCents: -1000),
        _item(
          uuid: 'c',
          description: 'Pfandflasche',
          amountCents: -1000,
          kind: LineItemKind.restposten,
        ),
      ]);

      expect(find.byType(Dismissible), findsNWidgets(2));
    },
  );

  testWidgets(
    'the footer shows the subtotal against the booking total',
    (tester) async {
      await pumpSection(
        tester,
        [
          _item(uuid: 'a', description: 'Milch', amountCents: -3000),
          _item(
            uuid: 'b',
            description: 'Pfandflasche',
            amountCents: -2000,
            kind: LineItemKind.restposten,
          ),
        ],
        parentAmountCents: -5000,
      );

      // Stops short of the currency symbol on purpose: de_DE puts a
      // non-breaking space in front of the € and the sign of a negative
      // total is not asserted here either.
      expect(find.textContaining('Σ'), findsOneWidget);
      expect(find.textContaining('von'), findsOneWidget);
      expect(find.textContaining('50,00'), findsOneWidget);
    },
  );

  group('editing the managed row', () {
    ProviderContainer buildSheetContainer() {
      final container = ProviderContainer(
        overrides: [
          categoriesProvider(false)
              .overrideWith((ref) => Stream.value(const <Category>[])),
          categoriesProvider(true)
              .overrideWith((ref) => Stream.value(const <Category>[])),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> openManagedSheet(WidgetTester tester) async {
      final parent = _transaction();
      final managed = _item(
        uuid: 'restposten-1',
        description: 'Pfandflasche',
        amountCents: -2000,
        kind: LineItemKind.restposten,
      );

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: buildSheetContainer(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showLineItemSheet(
                    context,
                    parent: parent,
                    existing: managed,
                  ),
                  child: const Text('Restposten bearbeiten öffnen'),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Restposten bearbeiten öffnen'));
      await settle(tester);
    }

    testWidgets('the sheet title reads "Restposten bearbeiten"', (
      tester,
    ) async {
      await openManagedSheet(tester);

      expect(find.text('Restposten bearbeiten'), findsOneWidget);
    });

    testWidgets('the amount field is disabled', (tester) async {
      await openManagedSheet(tester);

      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Betrag (automatisch)'),
      );
      expect(field.enabled, isFalse);
    });

    testWidgets('quantity and unit-price fields are not shown', (
      tester,
    ) async {
      await openManagedSheet(tester);

      expect(
        find.widgetWithText(TextFormField, 'Menge (optional)'),
        findsNothing,
      );
      expect(
        find.widgetWithText(TextFormField, 'Preis / Einheit (optional)'),
        findsNothing,
      );
    });
  });
}
