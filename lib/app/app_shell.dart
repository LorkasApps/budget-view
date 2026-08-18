import 'package:flutter/material.dart';

import '../features/account/presentation/account_list_screen.dart';
import '../features/analytics/presentation/monthly_category_report_screen.dart';
import 'menu_screen.dart';

/// Root surface of the app. The tabs live in an [IndexedStack] so switching
/// away and back keeps each screen's scroll position and filter state.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _index,
      children: const [
        AccountListScreen(),
        MonthlyCategoryReportScreen(),
        MenuScreen(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (index) => setState(() => _index = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'Konten',
        ),
        NavigationDestination(
          icon: Icon(Icons.donut_small_outlined),
          selectedIcon: Icon(Icons.donut_small),
          label: 'Report',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz_outlined),
          selectedIcon: Icon(Icons.more_horiz),
          label: 'Mehr',
        ),
      ],
    ),
  );
}
