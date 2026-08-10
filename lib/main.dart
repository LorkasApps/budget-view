import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/persistence/isar_db.dart';
import 'core/persistence/isar_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isar = await openAppIsar();
  runApp(
    ProviderScope(
      overrides: [isarProvider.overrideWithValue(isar)],
      child: const BudgetViewApp(),
    ),
  );
}

class BudgetViewApp extends StatelessWidget {
  const BudgetViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BudgetView',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('BudgetView'),
      ),
      body: const Center(
        child: Text('BudgetView'),
      ),
    );
  }
}
