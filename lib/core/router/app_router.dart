import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/screens/sign_in_screen.dart';

import 'package:inv_tracker/features/home/presentation/screens/home_shell_screen.dart';
import 'package:inv_tracker/features/overview/presentation/screens/overview_screen.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_list_screen.dart';
import 'package:inv_tracker/features/goals/presentation/screens/goals_screen.dart';
import 'package:inv_tracker/features/goals/presentation/screens/create_goal_screen.dart';
import 'package:inv_tracker/features/goals/presentation/screens/goal_details_screen.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_dashboard_screen.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_setup_screen.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_settings_screen.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/screens/portfolio_health_details_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';

// Notification Report Screens
import 'package:inv_tracker/features/notifications/presentation/screens/weekly_summary_report_screen.dart';
import 'package:inv_tracker/features/notifications/presentation/screens/monthly_summary_report_screen.dart';
import 'package:inv_tracker/features/notifications/presentation/screens/maturity_report_screen.dart';
import 'package:inv_tracker/features/notifications/presentation/screens/income_report_screen.dart';
import 'package:inv_tracker/features/notifications/presentation/screens/milestone_report_screen.dart';
import 'package:inv_tracker/features/notifications/presentation/screens/goal_milestone_report_screen.dart';
import 'package:inv_tracker/features/notifications/presentation/screens/goal_at_risk_report_screen.dart';
import 'package:inv_tracker/features/notifications/presentation/screens/goal_stale_report_screen.dart';
import 'package:inv_tracker/features/notifications/presentation/screens/risk_alert_report_screen.dart';
import 'package:inv_tracker/features/notifications/presentation/screens/idle_alert_report_screen.dart';
import 'package:inv_tracker/features/notifications/presentation/screens/fy_summary_report_screen.dart';

// Root navigator key - used for showing dialogs from anywhere in the app
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final securityState = ref.watch(securityProvider);
  final onboardingComplete = ref.watch(onboardingCompleteProvider);
  final analyticsObserver = ref.watch(analyticsObserverProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    observers: [if (analyticsObserver != null) analyticsObserver],
    redirect: (context, state) {
      // If auth or onboarding state is loading, we don't redirect yet
      if (authState.isLoading || authState.hasError) return null;
      if (onboardingComplete.isLoading) return null;

      final hasCompletedOnboarding = onboardingComplete.value ?? false;
      final isOnboardingRoute = state.uri.toString() == '/onboarding';

      // Show onboarding for first-time users (before sign-in)
      if (!hasCompletedOnboarding && !isOnboardingRoute) {
        return '/onboarding';
      }

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.uri.toString() == '/auth/signin';

      if (!isLoggedIn && !isLoggingIn && hasCompletedOnboarding) {
        return '/auth/signin';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      // Security Lock Check
      final isLocked = securityState.isLocked;
      final isLockScreen = state.uri.toString() == '/lock';

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
                builder: (context, state) => const OverviewScreen(),
              ),
            ],
          ),
          // Tab 2: Investments
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/investments',
                builder: (context, state) => const InvestmentListScreen(),
              ),
            ],
          ),
          // Tab 3: Goals
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/goals',
                builder: (context, state) => const GoalsScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const CreateGoalScreen(),
                  ),
                  GoRoute(
                    path: ':id',
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
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/auth/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) =>
            const PasscodeScreen(mode: PasscodeMode.unlock),
      ),
      GoRoute(
        path: '/onboarding',
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
        builder: (context, state) => const FireDashboardScreen(),
        routes: [
          GoRoute(
            path: 'setup',
            builder: (context, state) => const FireSetupScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const FireSettingsScreen(),
          ),
        ],
      ),
      // Portfolio Health route
      GoRoute(
        path: '/portfolio-health',
        builder: (context, state) => const PortfolioHealthDetailsScreen(),
      ),

      // ============ Notification Report Routes ============

      // Weekly Summary Report
      GoRoute(
        path: '/reports/weekly',
        builder: (context, state) => const WeeklySummaryReportScreen(),
      ),

      // Monthly Summary Report
      GoRoute(
        path: '/reports/monthly',
        builder: (context, state) => const MonthlySummaryReportScreen(),
      ),

      // Maturity Report
      GoRoute(
        path: '/reports/maturity/:investmentId',
        builder: (context, state) {
          final investmentId = state.pathParameters['investmentId']!;
          final daysToMaturity = int.tryParse(
            state.uri.queryParameters['daysToMaturity'] ?? '0',
          ) ?? 0;
          return MaturityReportScreen(
            investmentId: investmentId,
            daysToMaturity: daysToMaturity,
          );
        },
      ),

      // Income Report
      GoRoute(
        path: '/reports/income/:investmentId',
        builder: (context, state) {
          final investmentId = state.pathParameters['investmentId']!;
          return IncomeReportScreen(investmentId: investmentId);
        },
      ),

      // Milestone Report
      GoRoute(
        path: '/reports/milestone/:investmentId',
        builder: (context, state) {
          final investmentId = state.pathParameters['investmentId']!;
          final milestonePercent = int.tryParse(
            state.uri.queryParameters['milestonePercent'] ?? '0',
          ) ?? 0;
          return MilestoneReportScreen(
            investmentId: investmentId,
            milestonePercent: milestonePercent,
          );
        },
      ),

      // Goal Milestone Report
      GoRoute(
        path: '/reports/goal-milestone/:goalId',
        builder: (context, state) {
          final goalId = state.pathParameters['goalId']!;
          final milestonePercent = int.tryParse(
            state.uri.queryParameters['milestonePercent'] ?? '0',
          ) ?? 0;
          return GoalMilestoneReportScreen(
            goalId: goalId,
            milestonePercent: milestonePercent,
          );
        },
      ),

      // Goal At-Risk Report
      GoRoute(
        path: '/reports/goal-at-risk/:goalId',
        builder: (context, state) {
          final goalId = state.pathParameters['goalId']!;
          return GoalAtRiskReportScreen(goalId: goalId);
        },
      ),

      // Goal Stale Report
      GoRoute(
        path: '/reports/goal-stale/:goalId',
        builder: (context, state) {
          final goalId = state.pathParameters['goalId']!;
          final daysSinceActivity = int.tryParse(
            state.uri.queryParameters['daysSinceActivity'] ?? '0',
          ) ?? 0;
          return GoalStaleReportScreen(
            goalId: goalId,
            daysSinceActivity: daysSinceActivity,
          );
        },
      ),

      // Risk Alert Report
      GoRoute(
        path: '/reports/risk-alert',
        builder: (context, state) => const RiskAlertReportScreen(),
      ),

      // Idle Alert Report
      GoRoute(
        path: '/reports/idle/:investmentId',
        builder: (context, state) {
          final investmentId = state.pathParameters['investmentId']!;
          final daysSinceActivity = int.tryParse(
            state.uri.queryParameters['daysSinceActivity'] ?? '0',
          ) ?? 0;
          return IdleAlertReportScreen(
            investmentId: investmentId,
            daysSinceActivity: daysSinceActivity,
          );
        },
      ),

      // FY Summary Report
      GoRoute(
        path: '/reports/fy-summary',
        builder: (context, state) => const FYSummaryReportScreen(),
      ),
    ],
  );
});
