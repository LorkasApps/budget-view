import 'package:budget_view/core/money/money.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/features/analytics/domain/analytics_providers.dart';
import 'package:budget_view/features/analytics/domain/forecast.dart';
import 'package:budget_view/features/analytics/domain/monthly_category_report.dart';
import 'package:budget_view/features/analytics/presentation/forecast_screen.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _foodUuid = 'cat-food';

final _food = Category()
  ..uuid = _foodUuid
  ..name = 'Lebensmittel';

final _account = Account()
  ..uuid = 'acc-1'
  ..name = 'Girokonto'
  ..type = AccountType.giro
  ..openingBalanceCents = 0
  ..openingDate = DateTime(2026, 1, 1);

const _filter = ForecastFilter(
  categoryUuid: _foodUuid,
  anchorYear: 2026,
  anchorMonth: 3,
  windowMonths: 3,
  horizonMonths: 2,
);

MonthValue _month(int year, int month, int cents) =>
    MonthValue(year: year, month: month, cents: cents);

/// Answers per filter so a control tap is observable in the rendered result.
ForecastResult _resultFor(ForecastFilter filter) {
  if (filter.direction == ReportDirection.income) {
    return ForecastResult(
      history: [_month(2026, 1, 250000), _month(2026, 2, 250000), _month(2026, 3, 250000)],
      forecast: [_month(2026, 4, 250000)],
      slopeCentsPerMonth: 0,
      interceptCents: 250000,
      r2: 0,
    );
  }
  if (filter.windowMonths == null) {
    // "Alle" reaches further back and therefore projects higher.
    return ForecastResult(
      history: [
        _month(2025, 12, 500),
        _month(2026, 1, 1000),
        _month(2026, 2, 2000),
        _month(2026, 3, 3000),
      ],
      forecast: [_month(2026, 4, 4200), _month(2026, 5, 5100)],
      slopeCentsPerMonth: 870,
      interceptCents: 200,
      r2: 0.96,
    );
  }
  if (filter.windowMonths == 6) {
    return ForecastResult.insufficient([_month(2026, 2, 1000)]);
  }
  return ForecastResult(
    history: [_month(2026, 1, 1000), _month(2026, 2, 2000), _month(2026, 3, 3000)],
    forecast: [_month(2026, 4, 4000), _month(2026, 5, 5000)],
    slopeCentsPerMonth: 1000,
    interceptCents: 1000,
    r2: 1,
  );
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    ForecastFilter? initialFilter,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider(false).overrideWith((ref) => Stream.value([_account])),
          categoriesProvider(true).overrideWith((ref) => Stream.value([_food])),
          forecastProvider.overrideWith(
            (ref, filter) => Stream.value(_resultFor(filter)),
          ),
        ],
        child: MaterialApp(home: ForecastScreen(initialFilter: initialFilter)),
      ),
    );
    await settle(tester);
  }

  testWidgets('without a category it asks for one instead of charting', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      find.text('Kategorie wählen, um eine Prognose zu sehen'),
      findsOneWidget,
    );
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Kategorie wählen'), findsOneWidget);
  });

  testWidgets('a deep-linked filter renders chart, trend and projection', (
    tester,
  ) async {
    await pumpScreen(tester, initialFilter: _filter);

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Lebensmittel'), findsOneWidget);
    expect(find.text('Trend +${formatCentsEur(1000)} pro Monat'), findsOneWidget);
    expect(find.text('Anpassungsgüte 100 %'), findsOneWidget);
    expect(find.text('04/2026'), findsOneWidget);
    expect(find.text(formatCentsEur(4000)), findsOneWidget);
    expect(find.text(formatCentsEur(5000)), findsOneWidget);
  });

  testWidgets('the chart draws fit, history and a dashed projection', (
    tester,
  ) async {
    await pumpScreen(tester, initialFilter: _filter);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final bars = chart.data.lineBarsData;
    expect(bars, hasLength(3));
    expect(bars[1].spots, hasLength(3));
    // The dashed run repeats the last measured month so it connects.
    expect(bars[2].spots, hasLength(3));
    expect(bars[2].dashArray, isNotNull);
  });

  testWidgets('too short a history shows the minimum-months hint', (
    tester,
  ) async {
    await pumpScreen(tester, initialFilter: _filter.withWindow(6));

    expect(
      find.text('Zu wenige Daten für Prognose (mindestens 3 Monate)'),
      findsOneWidget,
    );
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('the window choice re-reads the forecast', (tester) async {
    await pumpScreen(tester, initialFilter: _filter);
    expect(find.text(formatCentsEur(4000)), findsOneWidget);

    await tester.tap(find.text('Alle'));
    await settle(tester);

    expect(find.text(formatCentsEur(4200)), findsOneWidget);
    expect(find.text(formatCentsEur(4000)), findsNothing);
  });

  testWidgets('the direction toggle switches to income', (tester) async {
    await pumpScreen(tester, initialFilter: _filter);

    await tester.tap(find.text('Einnahmen'));
    await settle(tester);

    expect(find.text(formatCentsEur(250000)), findsOneWidget);
    expect(find.text('Anpassungsgüte 0 %'), findsOneWidget);
  });

  testWidgets('the account chip filters the series', (tester) async {
    await pumpScreen(tester, initialFilter: _filter);
    expect(find.text('Alle Konten'), findsOneWidget);

    await tester.tap(find.text('Alle Konten'));
    await settle(tester);
    await tester.tap(find.text('Girokonto').last);
    await settle(tester);

    expect(find.text('Girokonto'), findsOneWidget);
  });
}
