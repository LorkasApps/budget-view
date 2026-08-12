import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/import/data/imported_source.dart';
import 'package:budget_view/features/import/domain/duplicate_checker.dart';
import 'package:budget_view/features/import/domain/import_providers.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/presentation/transaction_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Only the cancel path is exercised: confirming would reach the repository and
/// therefore Isar, which never completes inside `testWidgets` (see
/// `.claude/docs/errors.md`).
class _StubChecker implements DuplicateChecker {
  const _StubChecker(this.matches);

  final List<Transaction> matches;

  @override
  Future<List<Transaction>> findTransactionMatches(
    String dedupeHash, {
    required String accountUuid,
    bool excludeDeleted = true,
  }) async =>
      matches;

  @override
  Future<List<ImportedSource>> findDocumentMatches(String contentHash) async =>
      const [];
}

Transaction _existing({
  String uuid = 'existing-1',
  int amountCents = -4732,
  String description = 'Wochenendeinkauf',
}) {
  return Transaction()
    ..uuid = uuid
    ..accountUuid = 'account-1'
    ..amountCents = amountCents
    ..bookingDate = DateTime(2026, 8, 3)
    ..description = description
    ..counterparty = 'REWE';
}

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

  ProviderContainer containerWith(List<Transaction> matches) {
    final container = ProviderContainer(
      overrides: [
        accountsProvider(false).overrideWith((ref) => Stream.value([account])),
        categoriesProvider(false)
            .overrideWith((ref) => Stream.value([category])),
        categoriesProvider(true)
            .overrideWith((ref) => Stream.value([category])),
        duplicateCheckerProvider.overrideWithValue(_StubChecker(matches)),
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

  Future<void> pumpForm(
    WidgetTester tester,
    List<Transaction> matches,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: containerWith(matches),
        child: MaterialApp(
          home: TransactionFormScreen(initialAccountUuid: account.uuid),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Betrag (€)'),
      '47,32',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Beschreibung'),
      'Wochenendeinkauf',
    );
    await tester.tap(find.text('Kategorie'));
    await settle(tester);
    await tester.tap(find.text('Einkauf').last);
    await settle(tester);
  }

  testWidgets('an existing booking with the same hash is surfaced', (
    tester,
  ) async {
    await pumpForm(tester, [_existing()]);
    await fillForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
    await settle(tester);

    expect(find.text('Möglicher Doppel-Eintrag'), findsOneWidget);
    expect(
      find.textContaining('bereits eine Buchung mit gleichem Betrag'),
      findsOneWidget,
    );
    expect(find.textContaining('Wochenendeinkauf'), findsWidgets);
    expect(find.text('Trotzdem speichern'), findsOneWidget);
  });

  testWidgets('several matches are announced in the plural', (tester) async {
    await pumpForm(tester, [
      _existing(),
      _existing(uuid: 'existing-2', description: 'Nochmal dasselbe'),
    ]);
    await fillForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
    await settle(tester);

    expect(
      find.textContaining('bereits 2 Buchungen mit gleichem Betrag'),
      findsOneWidget,
    );
    expect(find.textContaining('Nochmal dasselbe'), findsOneWidget);
  });

  testWidgets('cancelling keeps the user on the form without saving', (
    tester,
  ) async {
    await pumpForm(tester, [_existing()]);
    await fillForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
    await settle(tester);
    await tester.tap(find.text('Abbrechen'));
    await settle(tester);

    expect(find.text('Möglicher Doppel-Eintrag'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Anlegen'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Beschreibung'),
      findsOneWidget,
    );
  });
}
