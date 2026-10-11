// The confirm dialog's action paints the colours of the theme it is in. In dark
// the destructive action is the dark error colour and the plain one the dark
// primary; the light values are a shade too dim on the dark dialog.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';

import '../../helpers/contrast.dart';

Future<void> _open(
  WidgetTester tester,
  Brightness brightness, {
  required bool isDestructive,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AppFeedback.showConfirmDialog(
              context: context,
              title: 'Title',
              message: 'Message',
              confirmText: 'Confirm',
              isDestructive: isDestructive,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Color _confirmColor(WidgetTester tester) =>
    tester.widget<Text>(find.text('Confirm')).style!.color!;

void main() {
  for (final (brightness, error, primary) in [
    (Brightness.light, AppColors.errorLight, AppColors.primaryLight),
    (Brightness.dark, AppColors.errorDark, AppColors.primaryDark),
  ]) {
    testWidgets('a destructive action is the error colour in $brightness', (
      tester,
    ) async {
      await _open(tester, brightness, isDestructive: true);
      expect(_confirmColor(tester), error);
    });

    testWidgets('a plain action is the primary colour in $brightness', (
      tester,
    ) async {
      await _open(tester, brightness, isDestructive: false);
      expect(_confirmColor(tester), primary);
    });
  }

  for (final destructive in [true, false]) {
    testWidgets(
      'the ${destructive ? 'destructive' : 'plain'} action reaches 4.5:1 on '
      'the dark dialog',
      (tester) async {
        await _open(tester, Brightness.dark, isDestructive: destructive);
        expect(
          contrastRatio(_confirmColor(tester), AppColors.surfaceDark),
          greaterThanOrEqualTo(kMinText),
        );
      },
    );
  }
}
