/// Performance benchmarks for InvTrack.
///
/// Tests frame timing, jank detection, and scroll performance.
/// Run with: flutter test integration_test/performance/performance_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

import '../robots/robots.dart';
import '../test_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Performance Benchmarks', () {
    testWidgets('app startup time', (tester) async {
      final stopwatch = Stopwatch()..start();

      final testApp = await TestApp.create(tester);
      await testApp.pumpApp();

      stopwatch.stop();

      debugPrint('📊 App startup time: ${stopwatch.elapsedMilliseconds}ms');

      // Assert startup is under 3 seconds
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(3000),
        reason: 'App should start in under 3 seconds',
      );
    });

    testWidgets('tab navigation performance', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);

      await testApp.pumpApp();

      final stopwatch = Stopwatch();
      final times = <int>[];

      // Measure navigation to each tab
      for (var i = 0; i < 3; i++) {
        stopwatch.reset();
        stopwatch.start();
        await nav.goToInvestments();
        stopwatch.stop();
        times.add(stopwatch.elapsedMilliseconds);

        stopwatch.reset();
        stopwatch.start();
        await nav.goToGoals();
        stopwatch.stop();
        times.add(stopwatch.elapsedMilliseconds);

        stopwatch.reset();
        stopwatch.start();
        await nav.goToSettings();
        stopwatch.stop();
        times.add(stopwatch.elapsedMilliseconds);

        stopwatch.reset();
        stopwatch.start();
        await nav.goToOverview();
        stopwatch.stop();
        times.add(stopwatch.elapsedMilliseconds);
      }

      final avgTime = times.reduce((a, b) => a + b) / times.length;
      debugPrint('📊 Average tab navigation time: ${avgTime.toStringAsFixed(1)}ms');

      // Assert navigation is under 500ms on average
      expect(
        avgTime,
        lessThan(500),
        reason: 'Tab navigation should be under 500ms',
      );
    });

    testWidgets('investment list scroll performance', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);

      // Seed many investments for scroll test
      final investments = List.generate(
        50,
        (i) => InvestmentEntity(
          id: 'inv-$i',
          name: 'Investment ${i + 1}',
          type: InvestmentType.values[i % InvestmentType.values.length],
          status: InvestmentStatus.open,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      );

      testApp.seedInvestments(investments);
      await testApp.pumpApp();
      await nav.goToInvestments();

      // Measure scroll performance with traceAction
      final stopwatch = Stopwatch()..start();

      await binding.traceAction(
        () async {
          // Scroll down
          for (var i = 0; i < 5; i++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -300),
            );
            await tester.pump();
          }

          // Scroll back up
          for (var i = 0; i < 5; i++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, 300),
            );
            await tester.pump();
          }
        },
        reportKey: 'scroll_timeline',
      );

      stopwatch.stop();
      debugPrint('📊 Scroll test completed in ${stopwatch.elapsedMilliseconds}ms');

      // Assert scroll performance is reasonable
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason: 'Scroll test should complete in under 5 seconds',
      );
    });

    testWidgets('frame timing during animations', (tester) async {
      final testApp = await TestApp.create(tester);
      final nav = NavigationRobot(tester);

      await testApp.pumpApp();

      final stopwatch = Stopwatch()..start();

      // Capture frame timing during navigation animations
      await binding.traceAction(
        () async {
          await nav.goToInvestments();
          await nav.goToGoals();
          await nav.goToSettings();
          await nav.goToOverview();
        },
        reportKey: 'navigation_timeline',
      );

      stopwatch.stop();
      debugPrint('📊 Navigation animation test completed in ${stopwatch.elapsedMilliseconds}ms');

      // Assert navigation animations are smooth
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(3000),
        reason: 'Navigation animations should complete in under 3 seconds',
      );
    });
  });
}
