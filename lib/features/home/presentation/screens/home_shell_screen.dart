import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';

class HomeShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShellScreen({super.key, required this.navigationShell});

  void _goBranch(int index) {
    // Always navigate to the root (first page) of the tab
    // When re-tapping same tab OR switching to a different tab
    navigationShell.goBranch(index, initialLocation: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Investments',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Goals',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.whiteLight,
        indicatorColor:
            (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                .withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
