import 'package:budget_view/app/menu_screen.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/features/analytics/presentation/forecast_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Bounded frames instead of `pumpAndSettle`: a route transition here is
  /// longer than the 400 ms this test first allowed, and settling is the thing
  /// that hangs when something schedules frames forever (see docs/errors.md).
  Future<void> pumpFrames(WidgetTester tester, {int steps = 24}) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpMenu(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The forecast screen reads this for its account chip once pushed.
          accountsProvider(false).overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: MenuScreen()),
      ),
    );
    await pumpFrames(tester, steps: 4);
  }

  testWidgets('lists the rare surfaces with an explaining subtitle', (
    tester,
  ) async {
    await pumpMenu(tester);

    expect(find.text('Mehr'), findsOneWidget);
    expect(find.text('Prognose'), findsOneWidget);
    expect(find.text('Lineare Hochrechnung je Kategorie'), findsOneWidget);
  });

  testWidgets('a tile pushes its screen, so back returns to the menu', (
    tester,
  ) async {
    await pumpMenu(tester);

    await tester.tap(find.text('Prognose'));
    await pumpFrames(tester);
    expect(find.byType(ForecastScreen), findsOneWidget);

    await tester.pageBack();
    await pumpFrames(tester);
    expect(find.byType(ForecastScreen), findsNothing);
    expect(find.text('Prognose'), findsOneWidget);
  });
}
