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
import 'package:budget_view/features/transaction/domain/transfer_pair_service.dart';
import 'package:budget_view/features/transaction/presentation/transaction_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Gegenkonto picker (ticket 042), widget-only: real Isar I/O never
/// completes inside `testWidgets` (see `.claude/docs/errors.md`), so every
/// provider the form can reach on the save path — including the two pairing
/// hooks ticket 042 added — is faked with pure Dart, the way
/// `manual_entry_suggest_test.dart` fakes the same screen's older providers.
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

class _NoopReconciler implements RestpostenReconciler {
  const _NoopReconciler();

  @override
  Future<void> reconcile(String transactionUuid) async {}
}

class _NoopLearnService implements TaggingLearnService {
  const _NoopLearnService();

  @override
  Future<void> learnFrom(Transaction transaction) async {}
}

class _NoSuggestions implements TaggingSuggestService {
  const _NoSuggestions();

  @override
  Future<List<CategorySuggestion>> suggest(String counterparty) async =>
      const [];
}

/// Records what the form saves. `implements` (not `extends`): the real
/// constructor wants a working `Isar` and `SyncAdapter`, never called here.
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

/// One call the form made to sync the counter-leg.
class SyncCall {
  SyncCall(this.source, this.targetAccountUuid);

  final Transaction source;
  final String? targetAccountUuid;
}

/// Records every `syncCounterpart` call instead of writing a second leg —
/// the point of this suite is the target picker's own items and the save
/// wiring, not the pairing logic already covered by
/// `transfer_pair_service_test.dart`.
class _RecordingTransferPairService implements TransferPairService {
  final List<SyncCall> syncCalls = [];

  @override
  Future<void> syncCounterpart(
    Transaction source, {
    required String? targetAccountUuid,
  }) async {
    syncCalls.add(SyncCall(source, targetAccountUuid));
  }

  @override
  Future<void> deletePair(Transaction transaction) async {}

  @override
  Future<Account?> counterpartAccountOf(Transaction transaction) async =>
      null;
}

void main() {
  final giro = Account()
    ..uuid = 'giro'
    ..name = 'Giro'
    ..type = AccountType.giro
    ..openingBalanceCents = 0
    ..openingDate = DateTime(2026, 1, 1);

  final tagesgeld = Account()
    ..uuid = 'tagesgeld'
    ..name = 'Tagesgeld'
    ..type = AccountType.tagesgeld
    ..openingBalanceCents = 0
    ..openingDate = DateTime(2026, 1, 1);

  // Archived: `buildContainer` below filters it out before it ever reaches
  // `accountsProvider(false)`, mirroring the real provider. The form does
  // no `.archived` check of its own on top of that.
  final altkonto = Account()
    ..uuid = 'altkonto'
    ..name = 'Altkonto'
    ..type = AccountType.giro
    ..openingBalanceCents = 0
    ..openingDate = DateTime(2026, 1, 1)
    ..archived = true;

  final category = Category()
    ..uuid = 'cat-1'
    ..name = 'Einkauf'
    ..iconName = 'shopping_cart'
    ..colorHex = '#43A047';

  ProviderContainer buildContainer({
    required List<Account> accounts,
    _RecordingTransactionRepository? repository,
    _RecordingTransferPairService? pairService,
  }) {
    // Mirrors `AccountRepository.findAll(includeArchived: false)`, which the
    // real `accountsProvider(false)` calls: an archived account never
    // reaches this stream, and the form does no `.archived` check of its
    // own on top of it.
    final visible = accounts.where((a) => !a.archived).toList();
    final container = ProviderContainer(
      overrides: [
        accountsProvider(false).overrideWith((ref) => Stream.value(visible)),
        categoriesProvider(false)
            .overrideWith((ref) => Stream.value([category])),
        categoriesProvider(true)
            .overrideWith((ref) => Stream.value([category])),
        duplicateCheckerProvider.overrideWithValue(const _NoDuplicates()),
        taggingSuggestServiceProvider
            .overrideWithValue(const _NoSuggestions()),
        transactionRepositoryProvider.overrideWithValue(
          repository ?? _RecordingTransactionRepository(),
        ),
        transferPairServiceProvider.overrideWithValue(
          pairService ?? _RecordingTransferPairService(),
        ),
        taggingLearnServiceProvider
            .overrideWithValue(const _NoopLearnService()),
        restpostenReconcilerProvider
            .overrideWithValue(const _NoopReconciler()),
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

  /// Pushed behind a button, as `manual_entry_suggest_test.dart` does it: a
  /// save that succeeds pops the form, and there is nothing to pop back to
  /// if the form itself is `MaterialApp.home`.
  Future<void> pumpForm(
    WidgetTester tester, {
    required List<Account> accounts,
    _RecordingTransactionRepository? repository,
    _RecordingTransferPairService? pairService,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: buildContainer(
          accounts: accounts,
          repository: repository,
          pairService: pairService,
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        TransactionFormScreen(initialAccountUuid: giro.uuid),
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

  Future<void> switchOnTransfer(WidgetTester tester) async {
    await tester.tap(find.text('Umbuchung'));
    await settle(tester);
  }

  Future<void> fillRequiredFields(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Betrag (€)'),
      '50,00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Beschreibung'),
      'Sparen',
    );
    await settle(tester);
  }

  /// The Gegenkonto field, found through its label rather than its type:
  /// the Konto field just above is a `DropdownButtonFormField<String>` too.
  Finder gegenkontoField() => find.ancestor(
        of: find.text('Gegenkonto (optional)'),
        matching: find.byType(DropdownButtonFormField<String>),
      );

  testWidgets(
    'the Gegenkonto picker is absent until Umbuchung is switched on',
    (tester) async {
      await pumpForm(tester, accounts: [giro, tagesgeld]);

      expect(find.text('Gegenkonto (optional)'), findsNothing);

      await switchOnTransfer(tester);
      expect(find.text('Gegenkonto (optional)'), findsOneWidget);

      await switchOnTransfer(tester);
      expect(find.text('Gegenkonto (optional)'), findsNothing);
    },
  );

  testWidgets(
    'its items exclude an archived account and the selected source',
    (tester) async {
      await pumpForm(tester, accounts: [giro, tagesgeld, altkonto]);
      await switchOnTransfer(tester);

      // Giro is the source (`initialAccountUuid`); its only occurrence so
      // far is the Konto field's own closed selection.
      expect(find.text('Giro'), findsOneWidget);
      expect(find.text('Tagesgeld'), findsNothing);
      expect(find.text('Altkonto'), findsNothing);

      await tester.tap(gegenkontoField());
      await settle(tester);

      // Opening the menu offers Tagesgeld, but never Giro — the source
      // stays excluded even from its own dropdown — and never Altkonto,
      // which the accounts stream above never even carried.
      expect(find.text('Giro'), findsOneWidget);
      expect(find.text('Tagesgeld'), findsOneWidget);
      expect(find.text('Altkonto'), findsNothing);
    },
  );

  testWidgets(
    'Kein Gegenkonto is offered and selecting it saves without error '
    '(032)',
    (tester) async {
      final repository = _RecordingTransactionRepository();
      final pairService = _RecordingTransferPairService();
      await pumpForm(
        tester,
        accounts: [giro, tagesgeld],
        repository: repository,
        pairService: pairService,
      );
      await switchOnTransfer(tester);
      await fillRequiredFields(tester);

      await tester.tap(gegenkontoField());
      await settle(tester);
      expect(find.text('Kein Gegenkonto'), findsWidgets);
      // The open menu's copy of the item, not the closed field underneath.
      await tester.tap(find.text('Kein Gegenkonto').last);
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
      await settle(tester);

      expect(find.text('Kategorie erforderlich'), findsNothing);
      final saved = repository.saved.single;
      expect(saved.kind, TransactionKind.transfer);
      expect(pairService.syncCalls.single.targetAccountUuid, isNull);
    },
  );
}
