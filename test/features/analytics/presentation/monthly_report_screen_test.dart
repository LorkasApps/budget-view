import 'package:budget_view/core/format/date_format.dart';
import 'package:budget_view/core/money/money.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/features/analytics/domain/analytics_providers.dart';
import 'package:budget_view/features/analytics/domain/monthly_category_report.dart';
import 'package:budget_view/features/analytics/presentation/monthly_category_report_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _foodUuid = 'cat-food';
const _drinksUuid = 'cat-drinks';
const _rentUuid = 'cat-rent';

CategoryRow _row({
  required String uuid,
  required String name,
  required int ownCents,
  required int rollupCents,
  int depth = 0,
  String? parentCategoryUuid,
}) => CategoryRow(
  categoryUuid: uuid,
  name: name,
  iconName: 'label',
  colorHex: '#607D8B',
  ownCents: ownCents,
  rollupCents: rollupCents,
  depth: depth,
  parentCategoryUuid: parentCategoryUuid,
);

final _expenses = MonthlyCategoryReport(
  rows: [
    _row(
      uuid: _foodUuid,
      name: 'Lebensmittel',
      ownCents: 1000,
      rollupCents: 1250,
    ),
    _row(uuid: _rentUuid, name: 'Miete', ownCents: 900, rollupCents: 900),
    _row(
      uuid: _drinksUuid,
      name: 'Getränke',
      ownCents: 250,
      rollupCents: 250,
      depth: 1,
      parentCategoryUuid: _foodUuid,
    ),
  ],
  uncategorizedCents: 300,
  totalCents: 2450,
);

// The uncategorized share keeps `Gesamt` distinct from the single row's amount,
// so an assertion on either one stays unambiguous.
final _income = MonthlyCategoryReport(
  rows: [
    _row(
      uuid: 'cat-salary',
      name: 'Gehalt',
      ownCents: 250000,
      rollupCents: 250000,
    ),
  ],
  uncategorizedCents: 500,
  totalCents: 250500,
);

final _giroOnly = MonthlyCategoryReport(
  rows: [_row(uuid: _rentUuid, name: 'Miete', ownCents: 900, rollupCents: 900)],
  uncategorizedCents: 100,
  totalCents: 1000,
);

final _account = Account()
  ..uuid = 'acc-1'
  ..name = 'Girokonto'
  ..type = AccountType.giro
  ..openingBalanceCents = 0
  ..openingDate = DateTime(2026, 1, 1);

final _now = DateTime.now();

/// The fake stands in for the service: it answers per filter, so a tap on a
/// filter control is observable as a different report.
MonthlyCategoryReport _reportFor(MonthlyReportFilter filter) {
  if (filter.year != _now.year || filter.month != _now.month) {
    return MonthlyCategoryReport.empty;
  }
  if (filter.direction == ReportDirection.income) return _income;
  if (filter.accountUuid != null) return _giroOnly;
  return _expenses;
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider(false).overrideWith((ref) => Stream.value([_account])),
          monthlyCategoryReportProvider.overrideWith(
            (ref, filter) => Stream.value(_reportFor(filter)),
          ),
        ],
        child: const MaterialApp(home: MonthlyCategoryReportScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('renders donut, total and one row per category', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Gesamt'), findsOneWidget);
    // Compared through the formatter: it puts a non-breaking space before €.
    expect(find.text(formatCentsEur(2450)), findsOneWidget);
    expect(find.text('Lebensmittel'), findsOneWidget);
    expect(find.text('Miete'), findsOneWidget);
    // Getränke sits one level down and only shows after a drilldown.
    expect(find.text('Getränke'), findsNothing);
  });

  testWidgets('uncategorized shows as its own row, outside the donut', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Ohne Kategorie'), findsOneWidget);
    expect(find.text(formatCentsEur(300)), findsOneWidget);
    expect(find.text('nicht im Diagramm'), findsOneWidget);
    final chart = tester.widget<PieChart>(find.byType(PieChart));
    expect(chart.data.sections, hasLength(2));
  });

  testWidgets('the month arrows move the report and hit the empty state', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(
      find.text(formatMonthYearDe(_now.year, _now.month)),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Nächster Monat'));
    await settle(tester);

    final next = DateTime(_now.year, _now.month + 1);
    expect(find.text(formatMonthYearDe(next.year, next.month)), findsOneWidget);
    expect(
      find.text('Keine Transaktionen für ${formatMonthYearDe(next.year, next.month)}'),
      findsOneWidget,
    );
  });

  testWidgets('the direction toggle switches to income', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Einnahmen'));
    await settle(tester);

    expect(find.text('Gehalt'), findsOneWidget);
    expect(find.text('Miete'), findsNothing);
    expect(find.text(formatCentsEur(250000)), findsOneWidget);
  });

  testWidgets('the account chip filters to one account', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Alle Konten'));
    await settle(tester);
    await tester.tap(find.text('Girokonto').last);
    await settle(tester);

    expect(find.text('Girokonto'), findsOneWidget);
    expect(find.text('Lebensmittel'), findsNothing);
    expect(find.text(formatCentsEur(900)), findsOneWidget);
  });

  testWidgets('tapping a parent drills into its children plus "(direkt)"', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Lebensmittel'));
    await settle(tester);

    expect(find.text('Lebensmittel (direkt)'), findsOneWidget);
    expect(find.text('Getränke'), findsOneWidget);
    // Total of the drilldown equals the row that was tapped. Scoped to the
    // pushed route — the root screen stays mounted underneath and shows the
    // same amount on its Lebensmittel row.
    expect(
      find.descendant(
        of: find.byType(CategorySubtreeReportScreen),
        matching: find.text(formatCentsEur(1250)),
      ),
      findsOneWidget,
    );
    // Own 10,00 € and the child's 2,50 € are the two slices here.
    final chart = tester.widget<PieChart>(
      find.descendant(
        of: find.byType(CategorySubtreeReportScreen),
        matching: find.byType(PieChart),
      ),
    );
    expect(chart.data.sections, hasLength(2));
  });

  testWidgets('a leaf category offers no drilldown', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Miete'));
    await settle(tester);

    expect(find.text('Miete (direkt)'), findsNothing);
  });
}
