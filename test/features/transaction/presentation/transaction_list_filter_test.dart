import 'package:budget_view/core/money/money.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_balance.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/tagging/domain/tagging_learn_service.dart';
import 'package:budget_view/features/tagging/domain/tagging_providers.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_providers.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:budget_view/features/transaction/domain/transfer_pair_service.dart';
import 'package:budget_view/features/transaction/presentation/transaction_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records saves and soft-deletes. The former only fires when a row's
/// category chip is reassigned by hand, which most of these tests never do;
/// the latter must never fire at all — deletion always goes through
/// `TransferPairService.deletePair` (ticket 042), never this repository
/// directly. `implements` (not `extends`) keeps the real constructor, which
/// wants a live `Isar`, out of it — see `manual_entry_suggest_test.dart`.
class _RecordingTransactionRepository implements TransactionRepository {
  final List<Transaction> saved = [];
  final List<String> softDeleteCalls = [];

  @override
  Future<Transaction> save(Transaction transaction) async {
    saved.add(transaction);
    return transaction;
  }

  @override
  Future<void> softDelete(String uuid) async {
    softDeleteCalls.add(uuid);
  }

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

class _NoopLearnService implements TaggingLearnService {
  @override
  Future<void> learnFrom(Transaction transaction) async {}
}

/// Records what the swipe-delete confirmation hands to the pairing service,
/// so a test can pin that call site without a real Isar behind it.
class _RecordingTransferPairService implements TransferPairService {
  final List<Transaction> deleteCalls = [];

  @override
  Future<void> syncCounterpart(
    Transaction source, {
    required String? targetAccountUuid,
  }) async {}

  @override
  Future<void> deletePair(Transaction transaction) async {
    deleteCalls.add(transaction);
  }

  @override
  Future<Account?> counterpartAccountOf(Transaction transaction) async =>
      null;
}

void main() {
  final account = Account()
    ..uuid = 'account-1'
    ..name = 'ING Giro'
    ..type = AccountType.giro
    ..openingBalanceCents = 0
    ..openingDate = DateTime(2026, 1, 1);

  const balance = AccountBalance(
    accountUuid: 'account-1',
    openingBalanceCents: 100000,
    transactionSumCents: -5000,
  );

  // A two-level tree plus an unrelated root, so a subtree pick has both
  // something to include (the child) and something to exclude.
  final freizeit = Category()
    ..uuid = 'cat-freizeit'
    ..name = 'Freizeit'
    ..iconName = 'sports_esports'
    ..colorHex = '#1E88E5';
  final kino = Category()
    ..uuid = 'cat-kino'
    ..name = 'Kino'
    ..parentUuid = 'cat-freizeit'
    ..iconName = 'local_movies'
    ..colorHex = '#1E88E5';
  final einkauf = Category()
    ..uuid = 'cat-einkauf'
    ..name = 'Einkauf'
    ..iconName = 'shopping_cart'
    ..colorHex = '#43A047';
  final categories = [freizeit, kino, einkauf];

  Transaction tx({
    required String uuid,
    required String description,
    required int amountCents,
    String? categoryUuid,
  }) {
    final now = DateTime(2026, 1, 1);
    return Transaction()
      ..uuid = uuid
      ..accountUuid = account.uuid
      ..categoryUuid = categoryUuid
      ..amountCents = amountCents
      ..bookingDate = now
      ..description = description
      ..createdAt = now
      ..updatedAt = now;
  }

  ProviderContainer buildContainer(
    List<Transaction> transactions, {
    _RecordingTransactionRepository? repository,
    _RecordingTransferPairService? pairService,
  }) {
    final container = ProviderContainer(
      overrides: [
        transactionsProvider(account.uuid)
            .overrideWith((ref) => Stream.value(transactions)),
        accountBalanceProvider(account.uuid)
            .overrideWith((ref) => Stream.value(balance)),
        categoriesProvider(false)
            .overrideWith((ref) => Stream.value(categories)),
        categoriesProvider(true)
            .overrideWith((ref) => Stream.value(categories)),
        transactionRepositoryProvider.overrideWithValue(
          repository ?? _RecordingTransactionRepository(),
        ),
        taggingLearnServiceProvider.overrideWithValue(_NoopLearnService()),
        transferPairServiceProvider.overrideWithValue(
          pairService ?? _RecordingTransferPairService(),
        ),
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

  Future<void> pumpScreen(
    WidgetTester tester,
    List<Transaction> transactions, {
    _RecordingTransactionRepository? repository,
    _RecordingTransferPairService? pairService,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: buildContainer(
          transactions,
          repository: repository,
          pairService: pairService,
        ),
        child: MaterialApp(home: TransactionListScreen(account: account)),
      ),
    );
    await settle(tester);
  }

  /// The chip is the only [InputChip] on screen, so it is unambiguous no
  /// matter what it is currently labelled.
  String chipLabel(WidgetTester tester) {
    final chip = tester.widget<InputChip>(find.byType(InputChip));
    return (chip.label as Text).data!;
  }

  /// Opens the sheet through the chip, then picks the row with
  /// [optionLabel]. Scoped to the sheet: a booking already wearing that same
  /// category renders the identical text in its own row, underneath.
  Future<void> pickCategoryFilterOption(
    WidgetTester tester,
    String optionLabel,
  ) async {
    await tester.tap(find.byType(InputChip));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(optionLabel),
      ),
    );
    await settle(tester);
  }

  testWidgets('typing in search narrows the visible rows', (tester) async {
    await pumpScreen(tester, [
      tx(uuid: 't1', description: 'Wocheneinkauf REWE', amountCents: -4200),
      tx(uuid: 't2', description: 'Kinobesuch', amountCents: -1500),
    ]);
    expect(find.text('Wocheneinkauf REWE'), findsOneWidget);
    expect(find.text('Kinobesuch'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kino');
    await settle(tester);

    expect(find.text('Wocheneinkauf REWE'), findsNothing);
    expect(find.text('Kinobesuch'), findsOneWidget);
  });

  testWidgets(
    'picking a category also narrows in its children\'s bookings',
    (tester) async {
      await pumpScreen(tester, [
        tx(
          uuid: 't1',
          description: 'Wocheneinkauf',
          amountCents: -4200,
          categoryUuid: einkauf.uuid,
        ),
        tx(
          uuid: 't2',
          description: 'Kinobesuch',
          amountCents: -1500,
          categoryUuid: kino.uuid,
        ),
        tx(
          uuid: 't3',
          description: 'Konzertkarte',
          amountCents: -3000,
          categoryUuid: freizeit.uuid,
        ),
      ]);

      await pickCategoryFilterOption(tester, 'Freizeit');

      expect(find.text('Wocheneinkauf'), findsNothing);
      expect(find.text('Kinobesuch'), findsOneWidget);
      expect(find.text('Konzertkarte'), findsOneWidget);
      expect(chipLabel(tester), 'Freizeit');
    },
  );

  testWidgets(
    'search and category combine to narrow further than either alone',
    (tester) async {
      await pumpScreen(tester, [
        tx(
          uuid: 't1',
          description: 'Kino Sonderangebot',
          amountCents: -800,
          categoryUuid: einkauf.uuid,
        ),
        tx(
          uuid: 't2',
          description: 'Kinobesuch mit Freunden',
          amountCents: -1500,
          categoryUuid: kino.uuid,
        ),
        tx(
          uuid: 't3',
          description: 'Konzertkarte ohne Filmwort',
          amountCents: -3000,
          categoryUuid: freizeit.uuid,
        ),
      ]);

      // Search alone: two of the three mention "kino".
      await tester.enterText(find.byType(TextField), 'kino');
      await settle(tester);
      expect(find.text('Kino Sonderangebot'), findsOneWidget);
      expect(find.text('Kinobesuch mit Freunden'), findsOneWidget);
      expect(find.text('Konzertkarte ohne Filmwort'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await settle(tester);

      // Category alone: two of the three sit under Freizeit.
      await pickCategoryFilterOption(tester, 'Freizeit');
      expect(find.text('Kino Sonderangebot'), findsNothing);
      expect(find.text('Kinobesuch mit Freunden'), findsOneWidget);
      expect(find.text('Konzertkarte ohne Filmwort'), findsOneWidget);

      // Both together: only one booking satisfies search and category.
      await tester.enterText(find.byType(TextField), 'kino');
      await settle(tester);
      expect(find.text('Kino Sonderangebot'), findsNothing);
      expect(find.text('Kinobesuch mit Freunden'), findsOneWidget);
      expect(find.text('Konzertkarte ohne Filmwort'), findsNothing);
    },
  );

  testWidgets(
    'no match offers a reset that restores everything',
    (tester) async {
      await pumpScreen(tester, [
        tx(
          uuid: 't1',
          description: 'Wocheneinkauf',
          amountCents: -4200,
          categoryUuid: einkauf.uuid,
        ),
        tx(
          uuid: 't2',
          description: 'Kinobesuch',
          amountCents: -1500,
          categoryUuid: kino.uuid,
        ),
      ]);

      await pickCategoryFilterOption(tester, 'Einkauf');
      expect(find.text('Wocheneinkauf'), findsOneWidget);
      expect(find.text('Kinobesuch'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz-nomatch');
      await settle(tester);

      expect(
        find.text('Keine Buchung passt zu Suche und Filter.'),
        findsOneWidget,
      );
      expect(find.text('Wocheneinkauf'), findsNothing);
      expect(find.text('Kinobesuch'), findsNothing);

      await tester.tap(find.text('Filter zurücksetzen'));
      await settle(tester);

      expect(find.text('Wocheneinkauf'), findsOneWidget);
      expect(find.text('Kinobesuch'), findsOneWidget);
      expect(chipLabel(tester), 'Alle Kategorien');
    },
  );

  testWidgets(
    'the balance header stays the same figure while filtering',
    (tester) async {
      await pumpScreen(tester, [
        tx(uuid: 't1', description: 'Wocheneinkauf', amountCents: -4200),
        tx(uuid: 't2', description: 'Kinobesuch', amountCents: -1500),
      ]);
      expect(find.text(formatCentsEur(balance.totalCents)), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'kino');
      await settle(tester);

      expect(find.text('Wocheneinkauf'), findsNothing);
      expect(find.text(formatCentsEur(balance.totalCents)), findsOneWidget);
    },
  );

  testWidgets(
    'the standalone "only uncategorized" toggle is gone',
    (tester) async {
      await pumpScreen(tester, const []);

      expect(find.byTooltip('Nur ohne Kategorie'), findsNothing);
    },
  );

  // Pins the accepted risk `transfer_pair_service.dart` names in its own
  // doc comment: a future write path could forget the service and call
  // `softDelete` directly. This is the guard, not a compiler.
  testWidgets(
    'swipe-delete goes through TransferPairService.deletePair, never '
    'TransactionRepository.softDelete directly (042)',
    (tester) async {
      final repository = _RecordingTransactionRepository();
      final pairService = _RecordingTransferPairService();
      await pumpScreen(
        tester,
        [tx(uuid: 't1', description: 'Wocheneinkauf', amountCents: -4200)],
        repository: repository,
        pairService: pairService,
      );

      await tester.drag(find.byType(Dismissible), const Offset(-1000, 0));
      await settle(tester);
      expect(find.text('"Wocheneinkauf" wird gelöscht.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
      await settle(tester);

      expect(pairService.deleteCalls.single.uuid, 't1');
      expect(repository.softDeleteCalls, isEmpty);
    },
  );
}
