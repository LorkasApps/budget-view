import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/transaction/presentation/transaction_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Manual entry must not save without a category. Database-free on purpose:
/// real Isar I/O never completes inside `testWidgets` (see
/// `.claude/docs/errors.md`), so the repository is simply never reached — the
/// assertions stop at the blocked save.
void main() {
  final account = Account()
    ..uuid = 'account-1'
    ..name = 'ING Giro'
    ..type = AccountType.giro
    ..openingBalanceCents = 0
    ..openingDate = DateTime(2026, 1, 1);

  final category = Category()
    ..uuid = 'cat-1'
    ..name = 'Einkauf'
    ..iconName = 'shopping_cart'
    ..colorHex = '#43A047';

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        accountsProvider(false).overrideWith((ref) => Stream.value([account])),
        categoriesProvider(false)
            .overrideWith((ref) => Stream.value([category])),
        categoriesProvider(true)
            .overrideWith((ref) => Stream.value([category])),
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

  Future<void> pumpForm(WidgetTester tester) async {
    // A tall surface so the form's ListView builds all of its children. At the
    // default 800x600 the save button is below the fold and therefore does not
    // exist in the tree at all.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: buildContainer(),
        child: MaterialApp(
          home: TransactionFormScreen(initialAccountUuid: account.uuid),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> fillRequiredFields(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Betrag (€)'),
      '47,32',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Beschreibung'),
      'Wochenendeinkauf',
    );
    await settle(tester);
  }

  testWidgets('an empty category is flagged as mandatory', (tester) async {
    await pumpForm(tester);

    expect(find.text('Kategorie'), findsOneWidget);
    expect(find.text('Pflichtfeld'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('saving without a category is refused', (tester) async {
    await pumpForm(tester);
    await fillRequiredFields(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
    await settle(tester);

    expect(find.text('Kategorie erforderlich'), findsOneWidget);
  });

  testWidgets('picking a category clears the mandatory hint', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.text('Kategorie'));
    await settle(tester);
    expect(find.text('Kategorie wählen'), findsOneWidget);

    await tester.tap(find.text('Einkauf'));
    await settle(tester);

    expect(find.text('Pflichtfeld'), findsNothing);
    expect(find.text('Einkauf'), findsOneWidget);
  });

  testWidgets('the picker offers no clear option for manual entry', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.text('Kategorie'));
    await settle(tester);

    expect(find.text('Keine Kategorie'), findsNothing);
  });
}
