import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/loading_skeletons.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';

void main() {
  testWidgets('ShimmerEffect should not have semantics initially', (
    tester,
  ) async {
    // 1. Pump the widget
    await tester.pumpWidget(
      const MaterialApp(
        home: ShimmerEffect(
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );

    // 2. Find the ShimmerEffect widget
    final shimmerEffect = find.byType(ShimmerEffect);
    expect(shimmerEffect, findsOneWidget);

    // 3. Verify that there is a semantics node with label 'Loading content'
    expect(find.bySemanticsLabel('Loading content'), findsOneWidget);
  });

  testWidgets('ShimmerEffect should accept custom semantic label', (
    tester,
  ) async {
    // 1. Pump the widget with custom label
    await tester.pumpWidget(
      const MaterialApp(
        home: ShimmerEffect(
          semanticLabel: 'Custom loading',
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );

    // 2. Verify that there is a semantics node with custom label
    expect(find.bySemanticsLabel('Custom loading'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading content'), findsNothing);
  });

  testWidgets('HeroCardSkeleton should have specific semantics', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HeroCardSkeleton()));
    expect(find.bySemanticsLabel('Loading summary'), findsOneWidget);
  });
}
