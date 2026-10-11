// A42: Income Guardian is hidden until something generates expected cash
// flows, so its monitor and sync services must not run for signed-in users
// while its flag is off. They read Firestore once per INCOME cash flow on
// every launch (ARCH-10) for a feature nobody can see.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/income_projection/data/services/income_guardian_monitor_service.dart';
import 'package:inv_tracker/features/income_projection/data/services/income_guardian_sync_service.dart';
import 'package:inv_tracker/features/income_projection/data/services/orphaned_expected_cash_flow_cleanup_service.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_guardian_service_providers.dart';
import 'package:inv_tracker/features/income_projection/presentation/widgets/income_guardian_service_initializer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockMonitor extends Mock implements IncomeGuardianMonitorService {}

class _MockSync extends Mock implements IncomeGuardianSyncService {}

class _MockCleanup extends Mock
    implements OrphanedExpectedCashFlowCleanupService {}

/// A cleanup that finishes at once, with [succeeds].
_MockCleanup _cleanup({bool succeeds = true}) {
  final cleanup = _MockCleanup();
  when(cleanup.runOnce).thenAnswer((_) async => succeeds);
  return cleanup;
}

Future<(_MockMonitor, _MockSync)> _pump(
  WidgetTester tester, {
  required bool overridesAllowed,
  Map<String, Object> stored = const {},
  OrphanedExpectedCashFlowCleanupService? cleanup,
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final monitor = _MockMonitor();
  final sync = _MockSync();
  when(monitor.startMonitoring).thenAnswer((_) async {});
  when(sync.startSync).thenAnswer((_) async {});
  when(monitor.stopMonitoring).thenReturn(null);
  when(sync.stopSync).thenReturn(null);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        featureFlagOverridesAllowedProvider.overrideWithValue(overridesAllowed),
        isAuthenticatedProvider.overrideWith((ref) => true),
        incomeGuardianMonitorServiceProvider.overrideWithValue(monitor),
        incomeGuardianSyncServiceProvider.overrideWithValue(sync),
        orphanedExpectedCashFlowCleanupServiceProvider.overrideWithValue(
          cleanup ?? _cleanup(),
        ),
      ],
      child: const IncomeGuardianServiceInitializer(child: SizedBox()),
    ),
  );
  await tester.pump();
  return (monitor, sync);
}

void main() {
  testWidgets('release build, signed in: the services do not start', (
    tester,
  ) async {
    final (monitor, sync) = await _pump(tester, overridesAllowed: false);

    verifyNever(monitor.startMonitoring);
    verifyNever(sync.startSync);
  });

  testWidgets('release build: a value stored on the device cannot start them', (
    tester,
  ) async {
    final (monitor, sync) = await _pump(
      tester,
      overridesAllowed: false,
      stored: {'feature_flag_income_guardian': true},
    );

    verifyNever(monitor.startMonitoring);
    verifyNever(sync.startSync);
  });

  testWidgets('with the flag on (Debug Settings) the services start once', (
    tester,
  ) async {
    final (monitor, sync) = await _pump(
      tester,
      overridesAllowed: true,
      stored: {'feature_flag_income_guardian': true},
    );

    verify(monitor.startMonitoring).called(1);
    verify(sync.startSync).called(1);
  });

  testWidgets('turning the flag off stops the running services once', (
    tester,
  ) async {
    final (monitor, sync) = await _pump(
      tester,
      overridesAllowed: true,
      stored: {'feature_flag_income_guardian': true},
    );
    verifyNever(monitor.stopMonitoring);
    verifyNever(sync.stopSync);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(IncomeGuardianServiceInitializer)),
    );
    await container
        .read(featureFlagsProvider.notifier)
        .setEnabled(FeatureFlag.incomeGuardian, false);
    await tester.pump();

    verify(monitor.stopMonitoring).called(1);
    verify(sync.stopSync).called(1);
  });

  // #917: orphaned expected payments are removed before anything reads them.
  group('orphaned expected payment cleanup', () {
    const flagOn = {'feature_flag_income_guardian': true};

    testWidgets('the services start only once the cleanup has finished', (
      tester,
    ) async {
      final finished = Completer<bool>();
      final cleanup = _MockCleanup();
      when(cleanup.runOnce).thenAnswer((_) => finished.future);

      final (monitor, sync) = await _pump(
        tester,
        overridesAllowed: true,
        stored: flagOn,
        cleanup: cleanup,
      );

      verify(cleanup.runOnce).called(1);
      verifyNever(monitor.startMonitoring);
      verifyNever(sync.startSync);

      finished.complete(true);
      await tester.pump();

      verify(monitor.startMonitoring).called(1);
      verify(sync.startSync).called(1);
    });

    testWidgets('a cleanup that failed does not keep the services from '
        'starting', (tester) async {
      final (monitor, sync) = await _pump(
        tester,
        overridesAllowed: true,
        stored: flagOn,
        cleanup: _cleanup(succeeds: false),
      );

      verify(monitor.startMonitoring).called(1);
      verify(sync.startSync).called(1);
    });

    testWidgets('turning the flag off while it runs starts nothing', (
      tester,
    ) async {
      final finished = Completer<bool>();
      final cleanup = _MockCleanup();
      when(cleanup.runOnce).thenAnswer((_) => finished.future);
      final (monitor, sync) = await _pump(
        tester,
        overridesAllowed: true,
        stored: flagOn,
        cleanup: cleanup,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(IncomeGuardianServiceInitializer)),
      );
      await container
          .read(featureFlagsProvider.notifier)
          .setEnabled(FeatureFlag.incomeGuardian, false);
      finished.complete(true);
      await tester.pump();

      verifyNever(monitor.startMonitoring);
      verifyNever(sync.startSync);
      verifyNever(monitor.stopMonitoring);
      verifyNever(sync.stopSync);
    });

    testWidgets('with the flag off it does not run', (tester) async {
      final cleanup = _cleanup();

      await _pump(tester, overridesAllowed: false, cleanup: cleanup);

      verifyNever(cleanup.runOnce);
    });
  });
}
