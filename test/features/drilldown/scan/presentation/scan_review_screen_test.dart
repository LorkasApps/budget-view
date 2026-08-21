import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_line_item_parser.dart';
import 'package:budget_view/features/drilldown/scan/presentation/scan_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/scan_test_support.dart';

/// Real Isar I/O never completes inside `testWidgets` (see
/// `.claude/docs/errors.md`); the category providers this screen touches read
/// Isar, so they are overridden the same way `line_item_edit_sheet_test.dart`
/// does it — resolved to an empty list instead of left pending.
ProviderContainer _buildContainer() {
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
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _buildContainer(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await pushScanReview(
                  context,
                  transaction: expenseTransaction(),
                  candidates: candidates,
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
}
