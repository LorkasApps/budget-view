import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/drilldown/data/line_item.dart';
import 'package:budget_view/features/drilldown/domain/line_item_providers.dart';
import 'package:budget_view/features/drilldown/domain/line_item_repository.dart';
import 'package:budget_view/features/drilldown/domain/restposten_reconciler.dart';
import 'package:budget_view/features/drilldown/presentation/line_item_edit_sheet.dart';
import 'package:budget_view/features/tagging/data/tagging_rule.dart';
import 'package:budget_view/features/tagging/domain/tagging_learn_service.dart';
import 'package:budget_view/features/tagging/domain/tagging_providers.dart';
import 'package:budget_view/features/tagging/domain/tagging_suggest_service.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The article suggestion in the line-item sheet outside the scan flow
/// (ticket 056), and what it teaches back on save.
///
/// Unlike `line_item_edit_sheet_test.dart`, which keeps a field invalid so the
/// save path is never entered, this suite drives a save to completion — so the
/// repository and the reconciler are faked too. Real Isar I/O never completes
/// inside `testWidgets`.
final _parent = Transaction()
  ..uuid = 'tx-1'
  ..accountUuid = 'acc-1'
  ..amountCents = -500
  ..bookingDate = DateTime(2026, 8, 1)
  ..description = 'Supermarkt'
  ..createdAt = DateTime(2026, 8, 1)
  ..updatedAt = DateTime(2026, 8, 1);

final _groceries = Category()
  ..uuid = 'cat-groceries'
  ..name = 'Einkauf'
  ..iconName = 'shopping_cart'
  ..colorHex = '#43A047';

final _drinks = Category()
  ..uuid = 'cat-drinks'
  ..name = 'Getränke'
  ..iconName = 'local_cafe'
  ..colorHex = '#1E88E5';

/// Article description → learned rules, strongest first.
class _FakeSuggestService implements TaggingSuggestService {
  _FakeSuggestService(this._byArticle);

  final Map<String, List<CategorySuggestion>> _byArticle;
  final List<TaggingMatchField> askedFields = [];

  @override
  Future<List<CategorySuggestion>> suggest(
    String matchValue, {
    required TaggingMatchField matchField,
  }) async {
    askedFields.add(matchField);
    return _byArticle[matchValue] ?? const [];
  }
}

/// One call the sheet made to the learn hook.
class LearnCall {
  LearnCall(this.description, this.categoryUuid, this.wasSuggested);

  final String description;
  final String? categoryUuid;
  final bool wasSuggested;
}

class _RecordingLearnService implements TaggingLearnService {
  final List<LearnCall> positionCalls = [];

  @override
  Future<void> learnFrom(Transaction transaction) async {}

  @override
  Future<void> learnFromPosition({
    required String description,
    required String? categoryUuid,
    required bool wasSuggested,
  }) async {
    positionCalls.add(LearnCall(description, categoryUuid, wasSuggested));
  }
}

class _NoopReconciler implements RestpostenReconciler {
  const _NoopReconciler();

  @override
  Future<void> reconcile(String transactionUuid) async {}
}

/// Accepts every write. `implements` (not `extends`): the real constructor wants
/// a live `Isar`, a `SyncAdapter` and a `TransactionRepository`.
class _RecordingLineItemRepository implements LineItemRepository {
  final List<LineItem> saved = [];

  @override
  Future<LineItem> save(LineItem item) async {
    saved.add(item);
    return item;
  }

  @override
  Future<LineItem> saveRestposten(LineItem item) async => item;

  @override
  Future<void> softDelete(String uuid) async {}

  @override
  Future<void> removeRestposten(String uuid) async {}

  @override
  Future<void> updateRestpostenDetails(
    String uuid, {
    required String description,
    String? categoryUuid,
  }) async {}

  @override
  Future<LineItem?> findRestposten(String transactionUuid) async => null;

  @override
  Future<LineItem?> findByUuid(String uuid) async => null;

  @override
  Future<List<LineItem>> findByTransaction(
    String transactionUuid, {
    bool includeDeleted = false,
  }) async =>
      const [];

  @override
  Future<List<LineItem>> findByTransactions(
    List<String> transactionUuids, {
    bool includeDeleted = false,
  }) async =>
      const [];

  @override
  Future<void> reorder(List<LineItem> ordered) async {}

  @override
  Future<int> sumForTransaction(String transactionUuid) async => 0;
}

void main() {
  CategorySuggestion hit(String uuid, String name, int hitCount) =>
      CategorySuggestion(
        categoryUuid: uuid,
        categoryName: name,
        hitCount: hitCount,
      );

  late _FakeSuggestService suggestService;
  late _RecordingLearnService learnService;
  late _RecordingLineItemRepository repository;

  ProviderContainer buildContainer(
    Map<String, List<CategorySuggestion>> rules,
  ) {
    suggestService = _FakeSuggestService(rules);
    learnService = _RecordingLearnService();
    repository = _RecordingLineItemRepository();
    final container = ProviderContainer(
      overrides: [
        categoriesProvider(false)
            .overrideWith((ref) => Stream.value([_groceries, _drinks])),
        categoriesProvider(true)
            .overrideWith((ref) => Stream.value([_groceries, _drinks])),
        taggingSuggestServiceProvider.overrideWithValue(suggestService),
        taggingLearnServiceProvider.overrideWithValue(learnService),
        lineItemRepositoryProvider.overrideWithValue(repository),
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

  Future<void> openSheet(
    WidgetTester tester, {
    Map<String, List<CategorySuggestion>> rules = const {},
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: buildContainer(rules),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showLineItemSheet(context, parent: _parent),
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

  /// Types an article and moves focus off the field, which is what triggers the
  /// lookup — the sheet suggests on blur, not per keystroke.
  Future<void> enterArticle(WidgetTester tester, String article) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Beschreibung'),
      article,
    );
    await tester.tap(find.widgetWithText(TextFormField, 'Betrag (€)'));
    await settle(tester);
  }

  testWidgets('an unambiguous article rule fills the category and marks it',
      (tester) async {
    await openSheet(tester, rules: {
      'Milch': [hit('cat-groceries', 'Einkauf', 4)],
    });
    await enterArticle(tester, 'Milch');

    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    expect(find.text('4×'), findsOneWidget);
    expect(suggestService.askedFields, contains(TaggingMatchField.description));
  });

  testWidgets('the lookup asks for article rules, never counterparty ones',
      (tester) async {
    await openSheet(tester);
    await enterArticle(tester, 'Milch');

    expect(
      suggestService.askedFields,
      everyElement(TaggingMatchField.description),
    );
  });

  testWidgets('a tie fills nothing', (tester) async {
    await openSheet(tester, rules: {
      'Milch': [
        hit('cat-groceries', 'Einkauf', 2),
        hit('cat-drinks', 'Getränke', 2),
      ],
    });
    await enterArticle(tester, 'Milch');

    // Nothing filled (ADR 0154), so no count — but the marker stays, because it
    // is the only way to reach the alternatives and break the tie.
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    expect(find.text('2×'), findsNothing);
    expect(find.text('Erbt von der Buchung (ohne Kategorie)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await settle(tester);

    expect(find.text('Vorschläge'), findsOneWidget);
  });

  testWidgets('picking the runner-up drops the suggestion marker',
      (tester) async {
    await openSheet(tester, rules: {
      'Milch': [
        hit('cat-groceries', 'Einkauf', 4),
        hit('cat-drinks', 'Getränke', 2),
      ],
    });
    await enterArticle(tester, 'Milch');

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await settle(tester);
    expect(find.text('Vorschläge'), findsOneWidget);

    await tester.tap(find.text('Getränke'));
    await settle(tester);

    // The field no longer wears a suggestion, so the count is gone; the icon
    // stays because rules for this article still exist.
    expect(find.text('4×'), findsNothing);
  });

  group('what the save teaches', () {
    Future<void> saveWith(WidgetTester tester, String amount) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Betrag (€)'),
        amount,
      );
      await settle(tester);
      await tester.tap(find.text('Hinzufügen'));
      await settle(tester);
    }

    testWidgets('an untouched suggestion is reported as a guess',
        (tester) async {
      await openSheet(tester, rules: {
        'Milch': [hit('cat-groceries', 'Einkauf', 4)],
      });
      await enterArticle(tester, 'Milch');
      await saveWith(tester, '1,19');

      expect(repository.saved, hasLength(1));
      final call = learnService.positionCalls.single;
      expect(call.description, 'Milch');
      expect(call.categoryUuid, 'cat-groceries');
      expect(call.wasSuggested, isTrue);
    });

    testWidgets('an overridden suggestion is reported as hand-set',
        (tester) async {
      await openSheet(tester, rules: {
        'Milch': [
          hit('cat-groceries', 'Einkauf', 4),
          hit('cat-drinks', 'Getränke', 2),
        ],
      });
      await enterArticle(tester, 'Milch');
      await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
      await settle(tester);
      await tester.tap(find.text('Getränke'));
      await settle(tester);
      await saveWith(tester, '1,19');

      final call = learnService.positionCalls.single;
      expect(call.categoryUuid, 'cat-drinks');
      expect(call.wasSuggested, isFalse);
    });

    testWidgets('a position left to inherit reports a null category',
        (tester) async {
      await openSheet(tester);
      await enterArticle(tester, 'Milch');
      await saveWith(tester, '1,19');

      final call = learnService.positionCalls.single;
      expect(call.categoryUuid, isNull);
      expect(call.wasSuggested, isFalse);
    });
  });
}
