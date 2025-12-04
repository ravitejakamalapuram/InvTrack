import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/screens/sign_in_screen.dart';

// Private navigator keys
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // If auth state is loading, we don't redirect yet
      if (authState.isLoading || authState.hasError) return null;

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.uri.toString() == '/auth/signin';

      if (!isLoggedIn && !isLoggingIn) {
        return '/auth/signin';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home Screen (Placeholder)')),
        ),
      ),
      GoRoute(
        path: '/auth/signin',
        builder: (context, state) => const SignInScreen(),
      ),
    ],
  );
});
