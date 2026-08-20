import 'package:flutter/material.dart';

import '../features/import/presentation/import_history_screen.dart';

/// Configuration and the data lists that go with it.
///
/// App-level like the menu screen: it collects surfaces from several domains, so
/// it belongs to none of them. Each row pushes a route, so back returns here.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Einstellungen')),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Import-Historie'),
          subtitle: const Text('Was importiert wurde, und Einträge löschen'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ImportHistoryScreen()),
          ),
        ),
      ],
    ),
  );
}
