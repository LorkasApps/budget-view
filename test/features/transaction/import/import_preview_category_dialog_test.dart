import 'dart:typed_data';

import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/import/data/imported_source.dart';
import 'package:budget_view/features/import/domain/duplicate_checker.dart';
import 'package:budget_view/features/import/domain/import_providers.dart';
import 'package:budget_view/features/tagging/domain/tagging_providers.dart';
import 'package:budget_view/features/tagging/domain/tagging_suggest_service.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/import/domain/import_flow_controller.dart';
import 'package:budget_view/features/transaction/import/pdf/parse_result.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser_providers.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser_registry.dart';
import 'package:budget_view/features/transaction/import/presentation/pdf_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI wiring only, deliberately without a database — see the comment on
/// `_StubParser` in `import_flow_widget_test.dart` for why.
class _StubParser implements PdfParser {
  @override
  String get id => 'stub-giro';

  @override
  String get displayName => 'Stub Giro';

  @override
  Future<double> canParse(Uint8List bytes) async => 0.9;

  @override
  Future<ParseResult> parse(Uint8List bytes) async => ParseResult(
        transactions: [
          ParsedTransactionCandidate(
            bookingDate: DateTime(2026, 7, 1),
            amountCents: -80000,
            description: 'Miete',
            counterparty: 'Vermieter GmbH',
          ),
          ParsedTransactionCandidate(
            bookingDate: DateTime(2026, 7, 5),
            amountCents: -4500,
            description: 'Wocheneinkauf',
            counterparty: 'REWE Berlin',
          ),
        ],
      );
}

class _NoDuplicates implements DuplicateChecker {
  const _NoDuplicates();

  @override
  Future<List<Transaction>> findTransactionMatches(
    String dedupeHash, {
    required String accountUuid,
    bool excludeDeleted = true,
  }) async =>
      const [];

  @override
  Future<List<ImportedSource>> findDocumentMatches(String contentHash) async =>
      const [];
}

/// Only 'REWE Berlin' has a learned rule, so 'Miete' parses in uncategorized.
class _FakeSuggestService implements TaggingSuggestService {
  const _FakeSuggestService();

  @override
  Future<List<CategorySuggestion>> suggest(String counterparty) async {
    if (counterparty != 'REWE Berlin') return const [];
    return const [
      CategorySuggestion(
        categoryUuid: 'cat-1',
        categoryName: 'Einkauf',
        hitCount: 3,
      ),
    ];
  }
}

void main() {
  late ProviderContainer container;

  final account = Account()
    ..uuid = 'account-1'
    ..name = 'ING Giro'
    ..type = AccountType.giro
    ..openingBalanceCents = 100000
    ..openingDate = DateTime(2026, 1, 1);

  final einkauf = Category()
    ..uuid = 'cat-1'
    ..name = 'Einkauf'
    ..iconName = 'shopping_cart'
    ..colorHex = '#43A047';

  final freizeit = Category()
    ..uuid = 'cat-2'
    ..name = 'Freizeit'
    ..iconName = 'sports_esports'
    ..colorHex = '#1E88E5';

  setUp(() {
    container = ProviderContainer(
      overrides: [
        pdfParserRegistryProvider.overrideWithValue(
          PdfParserRegistry()..register(_StubParser()),
        ),
        accountsProvider(false).overrideWith((ref) => Stream.value([account])),
        duplicateCheckerProvider.overrideWithValue(const _NoDuplicates()),
        taggingSuggestServiceProvider.overrideWithValue(
          const _FakeSuggestService(),
        ),
        categoriesProvider(false)
            .overrideWith((ref) => Stream.value([einkauf, freizeit])),
        categoriesProvider(true)
            .overrideWith((ref) => Stream.value([einkauf, freizeit])),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Frames are pumped with explicit durations rather than `pumpAndSettle`,
  /// for the same reason as `import_flow_widget_test.dart`: the account
  /// dropdown's indeterminate progress indicator would keep it spinning.
  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpFlow(WidgetTester tester) async {
    // The row list is long and the import screen is a plain ListView, so
    // off-screen rows never build without a tall surface.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PdfImportScreen(accountUuid: account.uuid)),
      ),
    );
    await settle(tester);
  }

  Future<void> loadAndParse(WidgetTester tester) async {
    final controller = container.read(importFlowProvider.notifier);
    await controller.loadDocument(
      Uint8List.fromList([1, 2, 3]),
      fileName: 'auszug.pdf',
    );
    await controller.parseDocument();
    await settle(tester);
  }

  Future<void> openRowDialog(WidgetTester tester, int index) async {
    await tester.tap(find.byIcon(Icons.edit_outlined).at(index));
    await settle(tester);
  }

  Future<void> openCategoryPicker(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.local_offer_outlined));
    await settle(tester);
  }

  Finder inDialog(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  testWidgets(
    'opening the edit dialog on a row without a category shows the '
    'placeholder',
    (tester) async {
      await pumpFlow(tester);
      await loadAndParse(tester);

      await openRowDialog(tester, 0);

      expect(inDialog(find.text('Keine Kategorie')), findsOneWidget);
    },
  );

  testWidgets(
    'opening the edit dialog on a row with a category shows its name',
    (tester) async {
      await pumpFlow(tester);
      await loadAndParse(tester);

      await openRowDialog(tester, 1);

      expect(inDialog(find.text('Einkauf')), findsOneWidget);
    },
  );

  testWidgets(
    'picking a category and confirming leaves the row carrying it',
    (tester) async {
      await pumpFlow(tester);
      await loadAndParse(tester);

      await openRowDialog(tester, 0);
      await openCategoryPicker(tester);
      await tester.tap(find.text('Freizeit'));
      await settle(tester);
      await tester.tap(find.text('Übernehmen'));
      await settle(tester);

      final row = container.read(importFlowProvider).rows[0];
      expect(row.categoryUuid, 'cat-2');
      expect(find.text('Freizeit'), findsOneWidget);
    },
  );

  testWidgets(
    'picking "Keine Kategorie" and confirming clears the row category',
    (tester) async {
      await pumpFlow(tester);
      await loadAndParse(tester);

      await openRowDialog(tester, 1);
      await openCategoryPicker(tester);
      await tester.tap(find.text('Keine Kategorie'));
      await settle(tester);
      await tester.tap(find.text('Übernehmen'));
      await settle(tester);

      final row = container.read(importFlowProvider).rows[1];
      expect(row.categoryUuid, isNull);
      expect(row.categorySuggested, isFalse);
    },
  );

  testWidgets(
    'cancelling after changing the category leaves it untouched',
    (tester) async {
      await pumpFlow(tester);
      await loadAndParse(tester);

      await openRowDialog(tester, 1);
      await openCategoryPicker(tester);
      await tester.tap(find.text('Freizeit'));
      await settle(tester);
      await tester.tap(find.text('Abbrechen'));
      await settle(tester);

      final row = container.read(importFlowProvider).rows[1];
      expect(row.categoryUuid, 'cat-1');
      expect(row.categorySuggested, isTrue);
    },
  );

  testWidgets(
    'the suggestion marker shows the hit count and disappears once the '
    'category is overridden',
    (tester) async {
      await pumpFlow(tester);
      await loadAndParse(tester);

      await openRowDialog(tester, 1);

      expect(inDialog(find.text('3×')), findsOneWidget);
      expect(
        inDialog(find.byIcon(Icons.auto_awesome_outlined)),
        findsOneWidget,
      );

      await openCategoryPicker(tester);
      await tester.tap(find.text('Freizeit'));
      await settle(tester);
      await tester.tap(find.text('Übernehmen'));
      await settle(tester);

      final row = container.read(importFlowProvider).rows[1];
      expect(row.categoryUuid, 'cat-2');
      expect(row.categorySuggested, isFalse);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
    },
  );
}
