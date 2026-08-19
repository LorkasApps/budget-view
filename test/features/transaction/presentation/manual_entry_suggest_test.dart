import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/drilldown/domain/line_item_providers.dart';
import 'package:budget_view/features/drilldown/domain/restposten_reconciler.dart';
import 'package:budget_view/features/import/data/imported_source.dart';
import 'package:budget_view/features/import/domain/duplicate_checker.dart';
import 'package:budget_view/features/import/domain/import_providers.dart';
import 'package:budget_view/features/tagging/domain/tagging_learn_service.dart';
import 'package:budget_view/features/tagging/domain/tagging_providers.dart';
import 'package:budget_view/features/tagging/domain/tagging_suggest_service.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_providers.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:budget_view/features/transaction/presentation/transaction_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real Isar I/O never completes inside `testWidgets` (see
/// `.claude/docs/errors.md`), so every provider this screen can reach on the
/// save path is faked with pure Dart — including the two persistence
/// providers, which no earlier manual-entry test needed because none of them
/// ever drove a save to completion.
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

/// Counterparty → learned suggestions, strongest first, mirroring the fake
/// `import_preview_suggest_test.dart` already uses for the same interface.
class _FakeSuggestService implements TaggingSuggestService {
  _FakeSuggestService(this._byCounterparty);

  final Map<String, List<CategorySuggestion>> _byCounterparty;

  @override
  Future<List<CategorySuggestion>> suggest(String counterparty) async =>
      _byCounterparty[counterparty] ?? const [];
}

class _NoopReconciler implements RestpostenReconciler {
  const _NoopReconciler();

  @override
  Future<void> reconcile(String transactionUuid) async {}
}

/// Records what the form hands to the learn hook, without touching the real
/// rule table behind it.
class _RecordingLearnService implements TaggingLearnService {
  final List<Transaction> calls = [];

  @override
  Future<void> learnFrom(Transaction transaction) async {
    calls.add(transaction);
  }
}

/// Records what the form saves. `implements` (not `extends`) means the real
/// constructor, which wants a working `Isar` and `SyncAdapter`, is never
/// called — only the public method surface has to line up.
class _RecordingTransactionRepository implements TransactionRepository {
  final List<Transaction> saved = [];

  @override
  Future<Transaction> save(Transaction transaction) async {
    saved.add(transaction);
    return transaction;
  }

  @override
  Future<void> softDelete(String uuid) async {}

  @override
  Future<Transaction?> findByUuid(String uuid) async => null;

  @override
  Future<List<Transaction>> findByAccount(
    String accountUuid, {
    bool includeDeleted = false,
  }) async =>
      const [];

  @override
  Future<List<Transaction>> findByDedupeHash(
    String dedupeHash, {
    required String accountUuid,
    bool includeDeleted = false,
  }) async =>
      const [];

  @override
  Future<int> countByCategory(String categoryUuid) async => 0;

  @override
  Future<int> sumForAccount(String accountUuid) async => 0;
}

void main() {
  final account = Account()
    ..uuid = 'account-1'
    ..name = 'ING Giro'
    ..type = AccountType.giro
    ..openingBalanceCents = 0
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

  ProviderContainer buildContainer({
    Map<String, List<CategorySuggestion>> suggestionsByCounterparty = const {},
    _RecordingTransactionRepository? repository,
    _RecordingLearnService? learnService,
  }) {
    final container = ProviderContainer(
      overrides: [
        accountsProvider(false).overrideWith((ref) => Stream.value([account])),
        categoriesProvider(false)
            .overrideWith((ref) => Stream.value([einkauf, freizeit])),
        categoriesProvider(true)
            .overrideWith((ref) => Stream.value([einkauf, freizeit])),
        duplicateCheckerProvider.overrideWithValue(const _NoDuplicates()),
        taggingSuggestServiceProvider.overrideWithValue(
          _FakeSuggestService(suggestionsByCounterparty),
        ),
        transactionRepositoryProvider.overrideWithValue(
          repository ?? _RecordingTransactionRepository(),
        ),
        taggingLearnServiceProvider.overrideWithValue(
          learnService ?? _RecordingLearnService(),
        ),
        restpostenReconcilerProvider.overrideWithValue(const _NoopReconciler()),
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

  /// Pushed behind a button, the way `scan_review_screen_test.dart` does it:
  /// a save that succeeds pops the form, and there is nothing to pop back to
  /// if the form itself is `MaterialApp.home`.
  Future<void> pumpForm(
    WidgetTester tester, {
    Map<String, List<CategorySuggestion>> suggestionsByCounterparty = const {},
    _RecordingTransactionRepository? repository,
    _RecordingLearnService? learnService,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: buildContainer(
          suggestionsByCounterparty: suggestionsByCounterparty,
          repository: repository,
          learnService: learnService,
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TransactionFormScreen(
                      initialAccountUuid: account.uuid,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('open'));
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

  /// Types into the counterparty field, then moves focus elsewhere — the
  /// form only suggests on blur, never per keystroke.
  Future<void> blurCounterparty(
    WidgetTester tester,
    String counterparty,
  ) async {
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Zahlungsempfänger / Absender (optional)',
      ),
      counterparty,
    );
    await tester.tap(find.widgetWithText(TextFormField, 'Notiz (optional)'));
    await settle(tester);
  }

  testWidgets('a suggested category fills in on blur', (tester) async {
    await pumpForm(
      tester,
      suggestionsByCounterparty: {
        'REWE Berlin': const [
          CategorySuggestion(
            categoryUuid: 'cat-1',
            categoryName: 'Einkauf',
            hitCount: 3,
          ),
        ],
      },
    );
    await fillRequiredFields(tester);

    await blurCounterparty(tester, 'REWE Berlin');

    expect(find.text('Vorschlag · 3×'), findsOneWidget);
    expect(find.text('Einkauf'), findsOneWidget);
  });

  testWidgets('a counterparty matching no rule shows no suggestion', (
    tester,
  ) async {
    await pumpForm(tester);
    await fillRequiredFields(tester);

    await blurCounterparty(tester, 'Unbekannt GmbH');

    expect(find.textContaining('Vorschlag'), findsNothing);
    expect(find.text('Pflichtfeld'), findsOneWidget);
  });

  testWidgets('picking a category by hand clears the suggestion hint', (
    tester,
  ) async {
    await pumpForm(
      tester,
      suggestionsByCounterparty: {
        'REWE Berlin': const [
          CategorySuggestion(
            categoryUuid: 'cat-1',
            categoryName: 'Einkauf',
            hitCount: 3,
          ),
        ],
      },
    );
    await fillRequiredFields(tester);
    await blurCounterparty(tester, 'REWE Berlin');
    expect(find.text('Vorschlag · 3×'), findsOneWidget);

    await tester.tap(find.text('Kategorie'));
    await settle(tester);
    await tester.tap(find.text('Freizeit'));
    await settle(tester);

    expect(find.text('Vorschlag · 3×'), findsNothing);
    expect(find.text('Freizeit'), findsOneWidget);
  });

  testWidgets('a single suggestion offers no alternatives button', (
    tester,
  ) async {
    await pumpForm(
      tester,
      suggestionsByCounterparty: {
        'REWE Berlin': const [
          CategorySuggestion(
            categoryUuid: 'cat-1',
            categoryName: 'Einkauf',
            hitCount: 3,
          ),
        ],
      },
    );
    await fillRequiredFields(tester);

    await blurCounterparty(tester, 'REWE Berlin');

    expect(find.text('Alternativen'), findsNothing);
  });

  testWidgets(
    'several suggestions offer alternatives, and picking one overrides',
    (tester) async {
      await pumpForm(
        tester,
        suggestionsByCounterparty: {
          'REWE Berlin': const [
            CategorySuggestion(
              categoryUuid: 'cat-1',
              categoryName: 'Einkauf',
              hitCount: 5,
            ),
            CategorySuggestion(
              categoryUuid: 'cat-2',
              categoryName: 'Freizeit',
              hitCount: 2,
            ),
          ],
        },
      );
      await fillRequiredFields(tester);
      await blurCounterparty(tester, 'REWE Berlin');
      expect(find.text('Vorschlag · 5×'), findsOneWidget);
      expect(find.text('Alternativen'), findsOneWidget);

      await tester.tap(find.text('Alternativen'));
      await settle(tester);
      expect(find.text('Vorschläge'), findsOneWidget);

      await tester.tap(find.text('Freizeit'));
      await settle(tester);

      expect(find.text('Vorschlag · 5×'), findsNothing);
      expect(find.text('Freizeit'), findsOneWidget);
    },
  );

  testWidgets(
    'saving an untouched suggestion persists it as auto-suggested',
    (tester) async {
      final repository = _RecordingTransactionRepository();
      final learnService = _RecordingLearnService();
      await pumpForm(
        tester,
        suggestionsByCounterparty: {
          'REWE Berlin': const [
            CategorySuggestion(
              categoryUuid: 'cat-1',
              categoryName: 'Einkauf',
              hitCount: 3,
            ),
          ],
        },
        repository: repository,
        learnService: learnService,
      );
      await fillRequiredFields(tester);
      await blurCounterparty(tester, 'REWE Berlin');

      await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
      await settle(tester);

      final saved = repository.saved.single;
      expect(saved.categoryUuid, 'cat-1');
      expect(saved.categoryAutoSuggested, isTrue);
      expect(learnService.calls.single.categoryAutoSuggested, isTrue);
    },
  );

  testWidgets(
    'saving an overridden suggestion persists it as hand-picked',
    (tester) async {
      final repository = _RecordingTransactionRepository();
      final learnService = _RecordingLearnService();
      await pumpForm(
        tester,
        suggestionsByCounterparty: {
          'REWE Berlin': const [
            CategorySuggestion(
              categoryUuid: 'cat-1',
              categoryName: 'Einkauf',
              hitCount: 3,
            ),
          ],
        },
        repository: repository,
        learnService: learnService,
      );
      await fillRequiredFields(tester);
      await blurCounterparty(tester, 'REWE Berlin');

      await tester.tap(find.text('Kategorie'));
      await settle(tester);
      await tester.tap(find.text('Freizeit'));
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
      await settle(tester);

      final saved = repository.saved.single;
      expect(saved.categoryUuid, 'cat-2');
      expect(saved.categoryAutoSuggested, isFalse);
      expect(learnService.calls.single.categoryAutoSuggested, isFalse);
    },
  );
}
