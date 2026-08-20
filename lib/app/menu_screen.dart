import 'package:flutter/material.dart';

import '../features/analytics/presentation/forecast_screen.dart';
import '../features/analytics/presentation/item_price_trend_screen.dart';
import 'settings_screen.dart';

/// Everything the bottom nav does not carry.
///
/// A destination earns a tab by how often it is opened; the rare ones live here
/// instead, so the bar stays at three while surfaces keep coming. Adding one is
/// a single [ListTile] — app-level on purpose, since it links across domains and
/// must not belong to any of them.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mehr')),
    body: ListView(
      children: [
        _MenuTile(
          icon: Icons.trending_up,
          title: 'Prognose',
          subtitle: 'Lineare Hochrechnung je Kategorie',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ForecastScreen()),
          ),
        ),
        _MenuTile(
          icon: Icons.price_change_outlined,
          title: 'Preistrends',
          subtitle: 'Preisverlauf einzelner Artikel aus Kassenbons',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ItemPriceTrendScreen(),
            ),
          ),
        ),
        _MenuTile(
          icon: Icons.settings_outlined,
          title: 'Einstellungen',
          subtitle: 'Import-Historie',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    ),
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;

  /// A surface nobody visits weekly has to explain itself in the list.
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
