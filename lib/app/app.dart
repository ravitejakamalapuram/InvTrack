import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';

/// The root widget of the InvTracker application.
///
/// This widget sets up the MaterialApp with the app's theme,
/// routing configuration, and global providers.
class InvTrackerApp extends ConsumerWidget {
  const InvTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'InvTracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}



