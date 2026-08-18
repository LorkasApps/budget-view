import 'package:budget_view/app/app_shell.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/features/account/presentation/account_list_screen.dart';
import 'package:budget_view/features/analytics/domain/analytics_providers.dart';
import 'package:budget_view/features/analytics/domain/monthly_category_report.dart';
import 'package:budget_view/features/analytics/presentation/forecast_screen.dart';
import 'package:budget_view/features/analytics/presentation/monthly_category_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider(false).overrideWith((ref) => Stream.value([])),
          totalBalanceProvider(false).overrideWith((ref) => Stream.value(0)),
          monthlyCategoryReportProvider.overrideWith(
            (ref, filter) => Stream.value(MonthlyCategoryReport.empty),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('starts on the accounts tab', (tester) async {
    await pumpShell(tester);

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.text('Konten'), findsWidgets);
    expect(find.text('Report'), findsWidgets);
    expect(find.text('Prognose'), findsWidgets);
  });

  testWidgets('tapping Report selects the second tab', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byIcon(Icons.donut_small_outlined));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets('tapping Prognose selects the third tab', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byIcon(Icons.trending_up_outlined));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('all tabs stay mounted, so their state survives a switch', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(find.byType(AccountListScreen, skipOffstage: false), findsOneWidget);
    expect(
      find.byType(MonthlyCategoryReportScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(ForecastScreen, skipOffstage: false), findsOneWidget);
  });
}
