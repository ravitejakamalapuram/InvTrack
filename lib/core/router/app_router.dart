import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/domain/entities/auth_state.dart';
import 'package:inv_tracker/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/presentation/screens/analytics_screen.dart';
import 'package:inv_tracker/presentation/screens/app_shell.dart';
import 'package:inv_tracker/presentation/screens/dashboard_screen.dart';
import 'package:inv_tracker/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/presentation/screens/investment_form_screen.dart';
import 'package:inv_tracker/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/presentation/screens/login_screen.dart';
import 'package:inv_tracker/presentation/screens/settings_screen.dart';

/// Route paths.
class AppRoutes {
  static const login = '/login';
  static const home = '/';
  static const investments = '/investments';
  static const investmentDetail = '/investments/:id';
  static const investmentNew = '/investments/new';
  static const investmentEdit = '/investments/:id/edit';
  static const analytics = '/analytics';
  static const settings = '/settings';
}

/// Global key for navigator.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Listenable that notifies when auth state changes.
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

/// Router provider.
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthStateNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      // If not logged in, redirect to login
      if (!isLoggedIn && !isLoggingIn) {
        return AppRoutes.login;
      }

      // If logged in and on login page, redirect to home
      if (isLoggedIn && isLoggingIn) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // Login route (no shell)
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // Main app shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.investments,
            pageBuilder: (context, state) => const NoTransitionPage(child: InvestmentListScreen()),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const InvestmentFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return InvestmentDetailScreen(investmentId: id);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return InvestmentFormScreen(investmentId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.analytics,
            pageBuilder: (context, state) => const NoTransitionPage(child: AnalyticsScreen()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

