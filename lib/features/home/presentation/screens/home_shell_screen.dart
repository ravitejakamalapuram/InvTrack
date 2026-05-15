import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';

class HomeShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShellScreen({super.key, required this.navigationShell});

  void _goBranch(int navigationIndex, bool isReportsEnabled) {
    // Map navigation bar index to router branch index
    // When Reports is disabled, indices shift:
    // NavBar: [Overview(0), Investments(1), Goals(2), Settings(3)]
    // Router: [Overview(0), Investments(1), Goals(2), Reports(3), Settings(4)]
    int routerIndex = navigationIndex;

    // If Reports is disabled and user clicks Settings (nav index 3),
    // we need to map to router index 4 (Settings branch)
    if (!isReportsEnabled && navigationIndex >= 3) {
      routerIndex = navigationIndex + 1; // Skip Reports branch
    }

    // Always navigate to the root (first page) of the tab
    navigationShell.goBranch(routerIndex, initialLocation: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReportsEnabled = ref.watch(isReportsTabEnabledProvider);

    // Build navigation destinations conditionally
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.pie_chart_outline),
        selectedIcon: Icon(Icons.pie_chart),
        label: 'Overview',
      ),
      const NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet),
        label: 'Investments',
      ),
      const NavigationDestination(
        icon: Icon(Icons.flag_outlined),
        selectedIcon: Icon(Icons.flag),
        label: 'Goals',
      ),
      if (isReportsEnabled)
        const NavigationDestination(
          icon: Icon(Icons.assessment_outlined),
          selectedIcon: Icon(Icons.assessment),
          label: 'Reports',
        ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    // Calculate the currently selected navigation bar index
    // Router index: [Overview(0), Investments(1), Goals(2), Reports(3), Settings(4)]
    // When Reports is disabled:
    // NavBar indices: [Overview(0), Investments(1), Goals(2), Settings(3)]
    int selectedNavIndex = navigationShell.currentIndex;
    if (!isReportsEnabled && navigationShell.currentIndex >= 4) {
      // User is on Settings (router index 4), map to nav index 3
      selectedNavIndex = 3;
    } else if (!isReportsEnabled && navigationShell.currentIndex == 3) {
      // User somehow accessed Reports (router index 3) - redirect to Overview
      selectedNavIndex = 0;
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedNavIndex,
        onDestinationSelected: (index) => _goBranch(index, isReportsEnabled),
        destinations: destinations,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.whiteLight,
        indicatorColor:
            (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                .withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
