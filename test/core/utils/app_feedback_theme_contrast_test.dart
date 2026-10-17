// The confirm dialog's action paints the colours of the theme it is in. In dark
// the destructive action is the dark error colour and the plain one the dark
// primary; the light values are a shade too dim on the dark dialog.
//
// The success and error snackbars are fills under a label and an icon. In light
// the fills are the deeper green and red, so the white label reads on them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
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
  // The theme builds text styles from fonts that are not bundled for tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final (name, show, fill)
      in <(String, void Function(BuildContext, String), Color)>[
        ('success', AppFeedback.showSuccess, AppColors.successLight),
        ('error', AppFeedback.showError, AppColors.errorLight),
      ]) {
    testWidgets(
      'the $name snackbar in light: label and icon read on the fill',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => show(context, 'Saved'),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final bar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(bar.backgroundColor, fill);
        final label = DefaultTextStyle.of(
          tester.element(find.text('Saved')),
        ).style.color!;
        expect(
          contrastRatio(label, fill),
          greaterThanOrEqualTo(kMinText),
          reason: 'the $name snackbar label',
        );
        final icon = tester
            .widget<Icon>(
              find.descendant(
                of: find.byType(SnackBar),
                matching: find.byType(Icon),
              ),
            )
            .color!;
        expect(
          contrastRatio(icon, fill),
          greaterThanOrEqualTo(kMinGraphic),
          reason: 'the $name snackbar icon',
        );
      },
    );
  }

  for (final (id, show, fill)
      in <(String, void Function(BuildContext, String), Color)>[
        (
          'snackbar-icon-success-dark',
          AppFeedback.showSuccess,
          AppColors.successDark,
        ),
        (
          'snackbar-icon-danger-dark',
          AppFeedback.showError,
          AppColors.errorDark,
        ),
      ]) {
    testWidgets('$id: the dark snackbar icon reads on the fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => show(context, 'Saved'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        fill,
      );
      final icon = tester
          .widget<Icon>(
            find.descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Icon),
            ),
          )
          .color!;
      expect(icon, AppColors.neutral900Light);
      expect(
        contrastRatio(icon, fill),
        greaterThanOrEqualTo(kMinGraphic),
        reason: id,
      );
    });
  }

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

  testWidgets(
    'confirm-dialog-destructive-light@dialog: the destructive action reaches '
    '4.5:1 on the light dialog',
    (tester) async {
      await _open(tester, Brightness.light, isDestructive: true);
      final dialog = tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(
        contrastRatio(_confirmColor(tester), dialog),
        greaterThanOrEqualTo(kMinText),
        reason: 'confirm-dialog-destructive-light@dialog',
      );
    },
  );

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
