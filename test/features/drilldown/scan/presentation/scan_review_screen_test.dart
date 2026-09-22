import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_line_item_parser.dart';
import 'package:budget_view/features/drilldown/scan/presentation/scan_review_screen.dart';
import 'package:budget_view/features/tagging/domain/tagging_suggest_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/scan_test_support.dart';

/// Real Isar I/O never completes inside `testWidgets` (see
/// `.claude/docs/errors.md`); the category providers this screen touches read
/// Isar, so they are overridden the same way `line_item_edit_sheet_test.dart`
/// does it — resolved to an empty list instead of left pending.
ProviderContainer _buildContainer([List<Category> categories = const []]) {
  final container = ProviderContainer(
    overrides: [
      categoriesProvider(false).overrideWith((ref) => Stream.value(categories)),
      categoriesProvider(true).overrideWith((ref) => Stream.value(categories)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pushes the screen behind a button, the way `pushScanReview` is meant to be
/// used, and hands the eventually-popped value to [onResult].
Future<void> _openReview(
  WidgetTester tester, {
  required List<LineItemCandidate> candidates,
  ValueChanged<List<LineItemCandidate>?>? onResult,
  List<String> unreadRows = const [],
  Map<int, List<CategorySuggestion>> suggestions = const {},
  List<Category> categories = const [],
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _buildContainer(categories),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await pushScanReview(
                  context,
                  transaction: expenseTransaction(),
                  candidates: candidates,
                  suggestions: suggestions,
                  unreadRows: unreadRows,
                );
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);

  await tester.tap(find.text('open'));
  await _settle(tester);
}

void main() {
  testWidgets(
    'a non-savable candidate checkbox is disabled, an ok one is not',
    (tester) async {
      await _openReview(
        tester,
        candidates: [
          LineItemCandidate(), // no description or amount: not savable
          defaultCandidates().first,
        ],
      );

      final checkboxes =
          tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(checkboxes, hasLength(2));
      expect(checkboxes[0].onChanged, isNull);
      expect(checkboxes[1].onChanged, isNotNull);
    },
  );

  testWidgets(
    'toggling a row off updates the "N übernehmen" label',
    (tester) async {
      await _openReview(tester, candidates: defaultCandidates());

      expect(find.text('2 übernehmen'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await _settle(tester);

      expect(find.text('1 übernehmen'), findsOneWidget);
    },
  );

  testWidgets('the delete icon removes a row', (tester) async {
    await _openReview(tester, candidates: defaultCandidates());

    expect(find.text('Milch'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await _settle(tester);

    expect(find.text('Milch'), findsNothing);
    expect(find.text('1 übernehmen'), findsOneWidget);
  });

  testWidgets('Verwerfen pops null', (tester) async {
    List<LineItemCandidate>? result;
    await _openReview(
      tester,
      candidates: defaultCandidates(),
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Verwerfen'));
    await _settle(tester);

    expect(result, isNull);
  });

  testWidgets(
    'the confirm button pops the current candidate list',
    (tester) async {
      List<LineItemCandidate>? result;
      await _openReview(
        tester,
        candidates: defaultCandidates(),
        onResult: (value) => result = value,
      );

      await tester.tap(find.byType(FilledButton));
      await _settle(tester);

      expect(result, isNotNull);
      expect(result!.map((c) => c.description), ['Milch', 'Brot']);
    },
  );

  group('unread rows (ticket 045)', () {
    testWidgets('are named and collapsed on arrival', (tester) async {
      await _openReview(
        tester,
        candidates: defaultCandidates(),
        unreadRows: const ['Bernard-Eyberg-Straße 80a', 'Vielen Dank'],
      );

      expect(find.text('2 nicht erkannte Zeilen'), findsOneWidget);
      // Collapsed, because on a receipt that read fine this list is the noise
      // ticket 035 removed.
      expect(find.text('Bernard-Eyberg-Straße 80a'), findsNothing);
    });

    testWidgets('expand to raw text and leave the candidates alone', (
      tester,
    ) async {
      await _openReview(
        tester,
        candidates: defaultCandidates(),
        unreadRows: const ['Bernard-Eyberg-Straße 80a'],
      );

      await tester.tap(find.text('1 nicht erkannte Zeilen'));
      await _settle(tester);

      expect(find.text('Bernard-Eyberg-Straße 80a'), findsOneWidget);
      // Text, not a candidate: no third checkbox appeared and the count stands.
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(find.text('2 übernehmen'), findsOneWidget);
    });

    testWidgets('are absent when everything was read', (tester) async {
      await _openReview(tester, candidates: defaultCandidates());

      expect(find.textContaining('nicht erkannte'), findsNothing);
    });
  });

  group('the suggestion marker (ticket 056)', () {
    final groceries = Category()
      ..uuid = 'cat-groceries'
      ..name = 'Einkauf'
      ..iconName = 'shopping_cart'
      ..colorHex = '#43A047';
    final drinks = Category()
      ..uuid = 'cat-drinks'
      ..name = 'Getränke'
      ..iconName = 'local_cafe'
      ..colorHex = '#1E88E5';

    LineItemCandidate milch({
      String? categoryUuid = 'cat-groceries',
      bool suggested = true,
    }) =>
        LineItemCandidate(description: 'Milch', amountCents: 119)
            .withCategory(categoryUuid, suggested: suggested);

    const oneRule = {
      0: [
        CategorySuggestion(
          categoryUuid: 'cat-groceries',
          categoryName: 'Einkauf',
          hitCount: 3,
        ),
      ],
    };

    const twoRules = {
      0: [
        CategorySuggestion(
          categoryUuid: 'cat-groceries',
          categoryName: 'Einkauf',
          hitCount: 3,
        ),
        CategorySuggestion(
          categoryUuid: 'cat-drinks',
          categoryName: 'Getränke',
          hitCount: 2,
        ),
      ],
    };

    testWidgets('a suggested row shows the marker and its hit count',
        (tester) async {
      await _openReview(
        tester,
        candidates: [milch()],
        suggestions: oneRule,
        categories: [groceries],
      );

      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
      expect(find.text('3×'), findsOneWidget);
    });

    testWidgets('a hand-set category of the same value wears no marker',
        (tester) async {
      await _openReview(
        tester,
        candidates: [milch(suggested: false)],
        suggestions: oneRule,
        categories: [groceries],
      );

      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
    });

    testWidgets('picking the runner-up counts as an override', (tester) async {
      List<LineItemCandidate>? result;
      await _openReview(
        tester,
        candidates: [milch()],
        suggestions: twoRules,
        categories: [groceries, drinks],
        onResult: (value) => result = value,
      );

      await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
      await _settle(tester);
      expect(find.text('Vorschläge'), findsOneWidget);

      await tester.tap(find.text('Getränke'));
      await _settle(tester);

      // The marker is gone because the row is no longer a guess, which is what
      // lets the learn hook raise the runner-up at confirm.
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);

      await tester.tap(find.text('1 übernehmen'));
      await _settle(tester);

      expect(result!.single.categoryUuid, 'cat-drinks');
      expect(result!.single.categorySuggested, isFalse);
    });

    testWidgets('a single rule offers no alternatives to open', (tester) async {
      await _openReview(
        tester,
        candidates: [milch()],
        suggestions: oneRule,
        categories: [groceries],
      );

      await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
      await _settle(tester);

      expect(find.text('Vorschläge'), findsNothing);
    });

    testWidgets('alle kategorisieren overrides a suggested row',
        (tester) async {
      List<LineItemCandidate>? result;
      await _openReview(
        tester,
        candidates: [milch()],
        suggestions: oneRule,
        categories: [groceries, drinks],
        onResult: (value) => result = value,
      );

      await tester.tap(find.byTooltip('Alle kategorisieren'));
      await _settle(tester);
      await tester.tap(find.text('Getränke'));
      await _settle(tester);

      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);

      await tester.tap(find.text('1 übernehmen'));
      await _settle(tester);

      expect(result!.single.categoryUuid, 'cat-drinks');
      expect(result!.single.categorySuggested, isFalse);
    });
  });
}
