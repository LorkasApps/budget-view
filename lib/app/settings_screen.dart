import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/import/presentation/import_history_screen.dart';
import '../features/tagging/presentation/tagging_rules_screen.dart';
import 'theme_mode_controller.dart';

/// Insertion order is the order the dialog offers them in.
const themeModeLabels = <ThemeMode, String>{
  ThemeMode.dark: 'Dunkel',
  ThemeMode.light: 'Hell',
  ThemeMode.system: 'Systemvorgabe',
};

/// Configuration and the data lists that go with it.
///
/// App-level like the menu screen: it collects surfaces from several domains, so
/// it belongs to none of them. Each row pushes a route, so back returns here.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Einstellungen')),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: const Text('Erscheinungsbild'),
          subtitle: Text(themeModeLabels[ref.watch(themeModeProvider)]!),
          onTap: () => _pickThemeMode(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Import-Historie'),
          subtitle: const Text('Was importiert wurde, und Einträge löschen'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ImportHistoryScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.label_outline),
          title: const Text('Tagging-Regeln'),
          subtitle: const Text('Gelernte Kategorie-Vorschläge kuratieren'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const TaggingRulesScreen()),
          ),
        ),
      ],
    ),
  );

  Future<void> _pickThemeMode(BuildContext context, WidgetRef ref) async {
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Erscheinungsbild'),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: ref.read(themeModeProvider),
            onChanged: (mode) => Navigator.of(dialogContext).pop(mode),
            child: Column(
              children: [
                for (final entry in themeModeLabels.entries)
                  RadioListTile<ThemeMode>(
                    value: entry.key,
                    title: Text(entry.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(themeModeProvider.notifier).select(picked);
    }
  }
}
