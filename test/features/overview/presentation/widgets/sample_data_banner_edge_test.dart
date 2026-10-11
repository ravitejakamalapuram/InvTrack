// The Overview owns the horizontal edge (ScreenSliver). The sample-data banner
// used to add a 16dp margin of its own on top, which put it at 32dp while the
// cards next to it sat at 16dp.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/screen_layout.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/sample_data_banner.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _SampleModeOn extends SampleDataModeNotifier {
  @override
  SampleDataState build() => const SampleDataState(isActive: true);
}

void main() {
  for (final scale in const [1.0, 2.0]) {
    testWidgets('banner starts and ends on the screen edge (text x$scale)', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 780)
        ..devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sampleDataModeProvider.overrideWith(_SampleModeOn.new)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  ScreenSliver(
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(const [
                        SampleDataBanner(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The visible box, not the widget: the widget's own box includes any
      // margin it adds to itself.
      final rect = tester.getRect(
        find
            .descendant(
              of: find.byType(SampleDataBanner),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(rect.left, closeTo(AppSpacing.screenEdge, 0.01));
      expect(rect.right, closeTo(360 - AppSpacing.screenEdge, 0.01));
    });
  }
}
