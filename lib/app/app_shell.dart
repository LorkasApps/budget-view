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
  Widget build(BuildContext context) => PopScope<void>(
    // Android's rule for bottom navigation: back from a secondary destination
    // returns to the start one, and only back from there leaves the app. The
    // IndexedStack carries no history of its own, so without this every tab is
    // an exit door. Pushed routes are unaffected — they are on top of this one.
    canPop: _index == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) setState(() => _index = 0);
    },
    child: Scaffold(
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
    ),
  );
}
