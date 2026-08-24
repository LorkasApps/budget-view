import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_shell.dart';
import 'app/theme_mode_controller.dart';
import 'core/persistence/isar_db.dart';
import 'core/persistence/isar_provider.dart';
import 'core/preferences/preference_store.dart';
import 'core/preferences/preference_store_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isar = await openAppIsar();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        preferenceStoreProvider.overrideWithValue(
          SharedPreferencesStore(preferences),
        ),
      ],
      child: const BudgetViewApp(),
    ),
  );
}

class BudgetViewApp extends ConsumerWidget {
  const BudgetViewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'BudgetView',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ref.watch(themeModeProvider),
      home: const AppShell(),
    );
  }
}
