import 'package:budget_view/app/settings_screen.dart';
import 'package:budget_view/app/theme_mode_controller.dart';
import 'package:budget_view/core/preferences/preference_store.dart';
import 'package:budget_view/core/preferences/preference_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real store wraps `shared_preferences`, which has no binding in the test
/// VM.
class _FakeStore implements PreferenceStore {
  _FakeStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async =>
      values[key] = value;
}

void main() {
  /// Bounded frames instead of `pumpAndSettle`, same reason as the menu screen
  /// test: settling is what hangs when something schedules frames forever.
  Future<void> pumpFrames(WidgetTester tester, {int steps = 24}) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Mirrors how `BudgetViewApp` hands the choice to `MaterialApp`, without
  /// pulling in `AppShell` and its Isar.
  Future<void> pumpSettings(WidgetTester tester, _FakeStore store) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferenceStoreProvider.overrideWithValue(store)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            themeMode: ref.watch(themeModeProvider),
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await pumpFrames(tester, steps: 4);
  }

  ThemeMode? appThemeMode(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;

  testWidgets('offers the three options and defaults to the OS setting', (
    tester,
  ) async {
    await pumpSettings(tester, _FakeStore());

    expect(appThemeMode(tester), ThemeMode.system);
    expect(find.text('Systemvorgabe'), findsOneWidget);

    await tester.tap(find.text('Erscheinungsbild'));
    await pumpFrames(tester);

    expect(find.byType(RadioListTile<ThemeMode>), findsNWidgets(3));
    expect(find.text('Dunkel'), findsOneWidget);
    expect(find.text('Hell'), findsOneWidget);
    // Twice now: the row's subtitle and the option it stands for.
    expect(find.text('Systemvorgabe'), findsNWidgets(2));
  });

  testWidgets('picking an option applies it at once and writes it down', (
    tester,
  ) async {
    final store = _FakeStore();
    await pumpSettings(tester, store);

    await tester.tap(find.text('Erscheinungsbild'));
    await pumpFrames(tester);
    await tester.tap(find.text('Dunkel'));
    await pumpFrames(tester);

    expect(appThemeMode(tester), ThemeMode.dark);
    expect(find.text('Dunkel'), findsOneWidget, reason: 'row subtitle');
    expect(store.values[ThemeModeController.preferenceKey], 'dark');
  });

  testWidgets('a stored choice survives the restart', (tester) async {
    await pumpSettings(
      tester,
      _FakeStore({ThemeModeController.preferenceKey: 'light'}),
    );

    expect(appThemeMode(tester), ThemeMode.light);
    expect(find.text('Hell'), findsOneWidget);
  });

  testWidgets('the other settings rows are untouched', (tester) async {
    await pumpSettings(tester, _FakeStore());

    expect(find.text('Import-Historie'), findsOneWidget);
    expect(find.text('Tagging-Regeln'), findsOneWidget);
  });
}
