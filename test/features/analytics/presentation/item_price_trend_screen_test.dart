import 'package:budget_view/core/format/date_format.dart';
import 'package:budget_view/core/money/money.dart';
import 'package:budget_view/features/analytics/domain/analytics_providers.dart';
import 'package:budget_view/features/analytics/domain/item_price_trend.dart';
import 'package:budget_view/features/analytics/presentation/item_price_chart_screen.dart';
import 'package:budget_view/features/analytics/presentation/item_price_trend_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _apfel = ItemGroup(
  normalizedKey: 'apfel',
  label: 'Apfel',
  purchaseCount: 3,
  latestUnitPriceCents: 149,
  latestDate: DateTime(2026, 3, 1),
);

final _kaffee = ItemGroup(
  normalizedKey: 'kaffee',
  label: 'Kaffee',
  purchaseCount: 1,
  latestUnitPriceCents: 599,
  latestDate: DateTime(2026, 2, 10),
);

final _groupsByQuery = <String, List<ItemGroup>>{
  'apfel': [_apfel],
  'kaffee': [_kaffee],
  'xyz': [],
};

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
          itemGroupSearchProvider.overrideWith(
            (ref, query) => Stream.value(_groupsByQuery[query] ?? const []),
          ),
        ],
        child: const MaterialApp(home: ItemPriceTrendScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> pumpChart(
    WidgetTester tester, {
    required ItemPriceSeries series,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemPriceSeriesProvider.overrideWith(
            (ref, key) => Stream.value(series),
          ),
        ],
        child: MaterialApp(
          home: ItemPriceChartScreen(
            normalizedKey: series.normalizedKey,
            title: series.label,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('a blank query shows the search hint, not a list', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      find.text('Artikel suchen, um seinen Preisverlauf zu sehen'),
      findsOneWidget,
    );
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('a result appears only after the debounce settles', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'apfel');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Apfel'), findsNothing);
    expect(
      find.text('Artikel suchen, um seinen Preisverlauf zu sehen'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 150));
    await settle(tester);

    expect(find.text('Apfel'), findsOneWidget);
  });

  testWidgets('a result row shows label, purchase count and price', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'apfel');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);

    expect(find.text('Apfel'), findsOneWidget);
    expect(find.text('3 Käufe'), findsOneWidget);
    expect(find.text(formatCentsEur(149)), findsOneWidget);
  });

  testWidgets('a single purchase uses the singular label', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'kaffee');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);

    expect(find.text('Kaffee'), findsOneWidget);
    expect(find.text('1 Kauf'), findsOneWidget);
  });

  testWidgets('no matches shows the not-found hint', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);

    expect(find.text('Keine Artikel gefunden'), findsOneWidget);
  });

  testWidgets('tapping a row opens the chart screen for that item', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'apfel');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);

    await tester.tap(find.text('Apfel'));
    await settle(tester);

    final chart = tester.widget<ItemPriceChartScreen>(
      find.byType(ItemPriceChartScreen),
    );
    expect(chart.normalizedKey, 'apfel');
    expect(chart.title, 'Apfel');
  });

  testWidgets('zero purchases shows the no-data hint', (tester) async {
    await pumpChart(tester, series: ItemPriceSeries.emptyFor('apfel'));

    expect(find.text('Keine Käufe erfasst'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('a single purchase shows its price but no chart', (
    tester,
  ) async {
    await pumpChart(
      tester,
      series: ItemPriceSeries(
        normalizedKey: 'apfel',
        label: 'Apfel',
        points: [PricePoint(date: DateTime(2026, 1, 1), unitPriceCents: 149)],
      ),
    );

    final price = formatCentsEur(149);
    expect(
      find.text('Nur ein Datenpunkt ($price) — kein Trend darstellbar'),
      findsOneWidget,
    );
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('several purchases draw one line with min/max markers', (
    tester,
  ) async {
    final points = [
      PricePoint(date: DateTime(2026, 1, 1), unitPriceCents: 100),
      PricePoint(date: DateTime(2026, 2, 1), unitPriceCents: 150),
      PricePoint(date: DateTime(2026, 3, 1), unitPriceCents: 120),
    ];
    await pumpChart(
      tester,
      series: ItemPriceSeries(
        normalizedKey: 'apfel',
        label: 'Apfel',
        points: points,
      ),
    );

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final bars = chart.data.lineBarsData;
    expect(bars, hasLength(1));
    expect(bars.single.spots, hasLength(3));

    final lines = chart.data.extraLinesData.horizontalLines;
    expect(lines, hasLength(2));
    final labels = lines.map((l) => l.label.labelResolver(l)).toSet();
    expect(labels, {
      'Max ${formatCentsEur(150)}',
      'Min ${formatCentsEur(100)}',
    });

    expect(find.text('3 Käufe erfasst'), findsOneWidget);
    final last = formatCentsEur(120);
    final lastDate = formatDateDe(DateTime(2026, 3, 1));
    expect(find.text('Zuletzt $last am $lastDate'), findsOneWidget);
  });

  testWidgets('equal prices draw a single flat marker line', (tester) async {
    final points = [
      PricePoint(date: DateTime(2026, 1, 1), unitPriceCents: 100),
      PricePoint(date: DateTime(2026, 2, 1), unitPriceCents: 100),
    ];
    await pumpChart(
      tester,
      series: ItemPriceSeries(
        normalizedKey: 'apfel',
        label: 'Apfel',
        points: points,
      ),
    );

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final lines = chart.data.extraLinesData.horizontalLines;
    expect(lines, hasLength(1));
    expect(
      lines.single.label.labelResolver(lines.single),
      'Preis ${formatCentsEur(100)}',
    );
  });
}
