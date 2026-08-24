import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:budget_view/core/preferences/preference_store.dart';
import 'package:budget_view/core/preferences/preference_store_provider.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/main.dart';

/// The real store wraps `shared_preferences`, which has no binding in the test
/// VM.
class _EmptyStore implements PreferenceStore {
  @override
  String? getString(String key) => null;

  @override
  Future<void> setString(String key, String value) async {}
}

void main() {
  testWidgets('app boots to the account list (empty state)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider(false)
              .overrideWith((ref) => Stream.value(const <Account>[])),
          preferenceStoreProvider.overrideWithValue(_EmptyStore()),
        ],
        child: const BudgetViewApp(),
      ),
    );
    // Two pumps: initial build (loading) + delivery of the stream value.
    await tester.pump();
    await tester.pump();

    // 'Konten' is both the list's app-bar title and the shell's tab label.
    expect(find.text('Konten'), findsWidgets);
    expect(find.text('Noch keine Konten. Lege eins an.'), findsOneWidget);
  });
}
