// The carousel on the Overview gives its cards a slot as tall as
// GoalCarouselCard.heightFor. The card grows with the text size, so the slot
// must too: this measures the card's own height from 1.0x to 2.0x text, in the
// real fonts, and fails when the slot gets smaller than the card (an overflow)
// or, once the card is taller than the minimum, more than a few dp bigger (a
// gap that grows).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_carousel_card.dart';

import 'card_guard_harness.dart';

GoalProgress _progress({
  String name = 'Emergency Fund',
  bool achieved = false,
}) {
  final goal = GoalEntity(
    id: 'g1',
    name: name,
    type: GoalType.targetAmount,
    targetAmount: 1000000,
    trackingMode: GoalTrackingMode.all,
    icon: '🛡️',
    colorValue: 0xFF3B82F6,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    currency: 'INR',
  );
  return GoalProgress(
    goal: goal,
    currentAmount: achieved ? 1000000 : 450000,
    targetAmount: 1000000,
    progressPercent: achieved ? 100 : 45,
    monthlyVelocity: 5000,
    monthlyIncome: 0,
    status: achieved ? GoalStatus.achieved : GoalStatus.onTrack,
    currentMilestone: GoalMilestone.half,
    achievedMilestones: const [GoalMilestone.half],
    linkedInvestmentCount: 3,
    calculatedAt: DateTime(2026, 10, 11),
  );
}

void main() {
  testWidgets('the slot is as tall as the card at every text scale', (
    tester,
  ) async {
    await runCardGuard(
      tester,
      width: 360,
      textScale: 1.0,
      body: (g) async {
        for (final achieved in const [false, true]) {
          for (var tenths = 10; tenths <= 20; tenths++) {
            final scale = tenths / 10;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            g.scope = '${achieved ? 'achieved' : 'active'} goal, text x$scale';
            await g.pump(
              Align(
                alignment: AlignmentDirectional.topStart,
                child: GoalCarouselCard(
                  progress: _progress(achieved: achieved),
                  width: 300,
                ),
              ),
            );
            final natural = tester
                .getSize(find.byType(GoalCarouselCard))
                .height;
            final slot = GoalCarouselCard.heightFor(
              tester.element(find.byType(GoalCarouselCard)),
            );
            if (slot < natural - 0.01) {
              g.fault(
                'the slot is ${g.dp(slot)}dp but the card needs ${g.dp(natural)}dp',
              );
            }
            if (natural > 110 && slot > natural + 4) {
              g.fault(
                'the slot is ${g.dp(slot)}dp for a card of ${g.dp(natural)}dp: '
                'more than 4dp of gap',
              );
            }
            if (slot < 110) g.fault('the slot is under 110dp (${g.dp(slot)})');
          }
        }
      },
    );
  });
}
