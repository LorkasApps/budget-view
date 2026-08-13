import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/drilldown/presentation/line_item_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Field validation only, deliberately without a database: real Isar I/O
/// never completes inside `testWidgets` (see `.claude/docs/errors.md`). Every
/// scenario here therefore leaves at least one required field invalid so
/// `_save` returns before it ever reaches `lineItemRepositoryProvider`.
void main() {
  ProviderContainer buildContainer() {
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

  Future<void> openSheet(WidgetTester tester) async {
    // A tall surface so the sheet's ListView lays out (and can be tapped)
    // without overflowing the default 800x600 test surface.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: buildContainer(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showLineItemSheet(
                  context,
                  transactionUuid: 'tx-1',
                  parentIsExpense: true,
                ),
                child: const Text('Position hinzufügen'),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Position hinzufügen'));
    await settle(tester);
  }

  Future<void> enterDescription(WidgetTester tester, String value) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Beschreibung'),
      value,
    );
    await settle(tester);
  }

  Future<void> enterAmount(WidgetTester tester, String value) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Betrag (€)'),
      value,
    );
    await settle(tester);
  }

  Future<void> tapAdd(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await settle(tester);
  }

  testWidgets('the category row shows the inherited placeholder', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Erbt von der Buchung'), findsOneWidget);
  });

  testWidgets('an empty description is refused', (tester) async {
    await openSheet(tester);
    await enterAmount(tester, '5,00');
    await tapAdd(tester);

    expect(find.text('Beschreibung erforderlich'), findsOneWidget);
  });

  testWidgets('a missing amount is refused', (tester) async {
    await openSheet(tester);
    await enterDescription(tester, 'Milch');
    await tapAdd(tester);

    expect(find.text('Betrag erforderlich'), findsOneWidget);
  });

  testWidgets('an unreadable amount is refused', (tester) async {
    await openSheet(tester);
    await enterDescription(tester, 'Milch');
    await enterAmount(tester, 'abc');
    await tapAdd(tester);

    expect(find.text('Betrag nicht lesbar'), findsOneWidget);
  });

  testWidgets('leaving quantity and unit price empty produces no error', (
    tester,
  ) async {
    await openSheet(tester);
    // Amount is valid but the description is deliberately left empty so the
    // form as a whole stays invalid and `_save` never reaches the repository
    // (and therefore never touches Isar) while we still inspect how the two
    // untouched optional fields validated.
    await enterAmount(tester, '5,00');
    await tapAdd(tester);

    expect(find.text('Beschreibung erforderlich'), findsOneWidget);
    expect(find.text('Menge nicht lesbar'), findsNothing);
    expect(find.text('Preis nicht lesbar'), findsNothing);
    expect(find.text('Menge muss größer als 0 sein'), findsNothing);
    expect(find.text('Preis muss größer als 0 sein'), findsNothing);
  });

  testWidgets(
    'a quantity/unit-price mismatch against the entered amount shows a warning',
    (tester) async {
      await openSheet(tester);
      await enterDescription(tester, 'Milch');
      await enterAmount(tester, '5,00');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Menge (optional)'),
        '2',
      );
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Preis / Einheit (optional)'),
        '0,89',
      );
      await settle(tester);

      // 2 x 0,89 € = 1,78 €, far off the entered 5,00 € — a warning must show.
      // Exact EUR formatting is locale-dependent, so we assert on the
      // unambiguous fragments instead of the full sentence.
      expect(find.textContaining('erwartet'), findsOneWidget);
      expect(find.textContaining('2 ×'), findsOneWidget);
    },
  );
}
