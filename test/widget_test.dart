import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:budget_view/main.dart';

void main() {
  testWidgets('App boots and shows BudgetView home', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BudgetViewApp()));

    expect(find.text('BudgetView'), findsWidgets);
  });
}
