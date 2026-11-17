import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_route_observer.dart';
import 'package:inv_tracker/core/analytics/analytics_screens.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/debug_mode_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/screens/sign_in_screen.dart';

import 'package:inv_tracker/features/home/presentation/screens/home_shell_screen.dart';
import 'package:inv_tracker/features/overview/presentation/screens/overview_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/features/goals/presentation/screens/goals_screen.dart';
import 'package:inv_tracker/features/goals/presentation/screens/create_goal_screen.dart';
import 'package:inv_tracker/features/goals/presentation/screens/goal_details_screen.dart';
import 'package:inv_tracker/core/notifications/notification_navigator.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_dashboard_screen.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_setup_screen.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_settings_screen.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/screens/portfolio_health_details_screen.dart';
import 'package:inv_tracker/features/digest/domain/monthly_digest.dart';
import 'package:inv_tracker/features/digest/presentation/screens/monthly_recap_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';

// Root navigator key - used for showing dialogs from anywhere in the app
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Tells the one router to re-run its redirects when state they read changes.
class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Built once. Everything the redirects depend on is read when they run and
/// pushed through [_RouterRefresh], so a lock, sign-in, onboarding or flag
/// change re-evaluates the redirects without recreating the router, which
/// would reset navigation to '/' and discard open forms (A27).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  late final GoRouter router;

  // Linking a guest to Google keeps the UID and must not refresh; redirect()
  // uses only these fields of the auth state.
  ref.listen(
    authStateProvider.select(
      (state) => (state.isLoading, state.hasError, state.value?.id),
    ),
    (previous, next) {
      refresh.refresh();
      // A direct switch from one signed-in user to another must not keep the
      // previous user's pages; sign-out and first sign-in already redirect.
      final (_, _, before) = previous ?? (false, false, null);
      final (_, _, after) = next;
      if (before != null && after != null && before != after) {
        router.go('/');
      }
    },
  );
  ref.listen(securityProvider.select((s) => s.isLocked), (_, _) {
    refresh.refresh();
  });
  ref.listen(onboardingCompleteProvider, (_, _) => refresh.refresh());

  router = GoRouter(
    refreshListenable: refresh,
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    // Route paths are diagnostics; release builds must not log them (A35).
    debugLogDiagnostics: ref.read(developerToolsAvailableProvider),
    // The one observer: go_router forwards the tabs' own Navigators to it, so
    // none of the tab branches gets another (it would log every tab twice).
    observers: [AnalyticsRouteObserver(ref.read(analyticsServiceProvider))],
    redirect: (context, state) {
      final (authLoading, authFailed, signedInUserId) = ref.read(
        authStateProvider.select(
          (state) => (state.isLoading, state.hasError, state.value?.id),
        ),
      );
      final onboardingComplete = ref.read(onboardingCompleteProvider);
      final isLocked = ref.read(securityProvider).isLocked;
      final isLockScreen = state.uri.toString() == '/lock';

      // While auth or onboarding state is loading, only the lock applies:
      // no portfolio frame may render before it.
      if (authLoading || authFailed || onboardingComplete.isLoading) {
        if (isLocked) return isLockScreen ? null : '/lock';
        return isLockScreen ? '/' : null;
      }

      final hasCompletedOnboarding = onboardingComplete.value ?? false;
      final isOnboardingRoute = state.uri.toString() == '/onboarding';

      // Show onboarding for first-time users (before sign-in)
      if (!hasCompletedOnboarding && !isOnboardingRoute) {
        return '/onboarding';
      }

      final isLoggedIn = signedInUserId != null;
      final isLoggingIn = state.uri.toString() == '/auth/signin';

      if (!isLoggedIn && !isLoggingIn && hasCompletedOnboarding) {
        return '/auth/signin';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      // Security Lock Check
      if (isLoggedIn && isLocked && !isLockScreen) {
        return '/lock';
      }

      if (isLoggedIn && !isLocked && isLockScreen) {
        return '/';
      }

      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Overview (Home)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: AnalyticsScreens.overview,
                builder: (context, state) => const OverviewScreen(),
              ),
            ],
          ),
          // Tab 2: Investments
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/investments',
                name: AnalyticsScreens.investments,
                builder: (context, state) => const InvestmentListScreen(),
                // Routes, not imperative pushes, so the lock redirect above
                // applies to them (A07). They cover the whole screen.
                routes: [
                  GoRoute(
                    path: ':id',
                    name: AnalyticsScreens.investmentDetail,
                    parentNavigatorKey: rootNavigatorKey,
                    // The caller passes the investment it already loaded.
                    redirect: (context, state) =>
                        state.extra is InvestmentEntity ? null : '/investments',
                    builder: (context, state) => InvestmentDetailScreen(
                      investment: state.extra! as InvestmentEntity,
                    ),
                  ),
                  GoRoute(
                    path: ':id/add-cash-flow',
                    name: AnalyticsScreens.addCashFlow,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        NotificationNavigator.addCashFlowScreen(
                          state.pathParameters['id']!,
                          state.uri.queryParameters,
                        ),
                  ),
                ],
              ),
            ],
          ),
          // Tab 3: Goals
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/goals',
                name: AnalyticsScreens.goals,
                builder: (context, state) => const GoalsScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    name: AnalyticsScreens.goalCreate,
                    builder: (context, state) => const CreateGoalScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: AnalyticsScreens.goalDetail,
                    builder: (context, state) {
                      final goalId = state.pathParameters['id']!;
                      return GoalDetailsScreen(goalId: goalId);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Tab 4: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: AnalyticsScreens.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/auth/signin',
        name: AnalyticsScreens.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/lock',
        name: AnalyticsScreens.lock,
        builder: (context, state) =>
            const PasscodeScreen(mode: PasscodeMode.unlock),
      ),
      GoRoute(
        path: '/onboarding',
        name: AnalyticsScreens.onboarding,
        builder: (context, state) => OnboardingScreen(
          onComplete: () {
            // Invalidate the provider so it re-checks
            // Then navigate to sign-in
            ref.invalidate(onboardingCompleteProvider);
          },
        ),
      ),
      // FIRE Number routes
      GoRoute(
        path: '/fire',
        name: AnalyticsScreens.fire,
        builder: (context, state) => const FireDashboardScreen(),
        routes: [
          GoRoute(
            path: 'setup',
            name: AnalyticsScreens.fireSetup,
            builder: (context, state) => const FireSetupScreen(),
          ),
          GoRoute(
            path: 'settings',
            name: AnalyticsScreens.fireSettings,
            builder: (context, state) => const FireSettingsScreen(),
          ),
        ],
      ),
      // Portfolio Health route
      GoRoute(
        path: '/portfolio-health',
        name: AnalyticsScreens.portfolioHealth,
        builder: (context, state) => const PortfolioHealthDetailsScreen(),
      ),
      // Monthly recap, opened from its notification
      GoRoute(
        path: '/recap/:month',
        name: AnalyticsScreens.monthlyRecap,
        // A malformed month lands on Overview.
        redirect: (context, state) {
          try {
            DigestMonth.parse(state.pathParameters['month'] ?? '');
            return null;
          } on FormatException {
            return '/';
          }
        },
        builder: (context, state) => MonthlyRecapScreen(
          month: DigestMonth.parse(state.pathParameters['month']!),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
