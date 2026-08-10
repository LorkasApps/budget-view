import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/main.dart';

void main() {
  testWidgets('app boots to the account list (empty state)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider(false)
              .overrideWith((ref) => Stream.value(const <Account>[])),
        ],
        child: const BudgetViewApp(),
      ),
    );
    // Two pumps: initial build (loading) + delivery of the stream value.
    await tester.pump();
    await tester.pump();

    expect(find.text('Konten'), findsOneWidget);
    expect(find.text('Noch keine Konten. Lege eins an.'), findsOneWidget);
  });
}
