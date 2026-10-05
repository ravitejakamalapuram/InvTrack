// A11 (#755, UX-10, PLAN-07, PLAN-05, GAP2-01): FIRE setup never swaps the
// user's expenses for ₹50,000, keeps the target age above the current age,
// and stores a birth year and the base currency.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_notifier.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_setup_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _RecordingNotifier extends FireSettingsNotifier {
  _RecordingNotifier(this.saved);

  final List<FireSettingsEntity> saved;

  @override
  Future<void> saveSettings(FireSettingsEntity settings) async {
    saved.add(settings);
  }
}

Future<List<FireSettingsEntity>> _pumpSetup(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final saved = <FireSettingsEntity>[];
  final router = GoRouter(
    initialLocation: '/fire/setup',
    routes: [
      GoRoute(
        path: '/fire',
        builder: (_, _) => const Scaffold(body: Text('FIRE dashboard')),
        routes: [
          GoRoute(path: 'setup', builder: (_, _) => const FireSetupScreen()),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        fireSettingsNotifierProvider.overrideWith(
          () => _RecordingNotifier(saved),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return saved;
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.byType(GradientButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('"75,000" is saved as ₹75,000 a month, not ₹50,000', (
    tester,
  ) async {
    final saved = await _pumpSetup(tester);

    await _continue(tester); // ages
    await tester.enterText(find.byType(TextFormField), '75,000');
    await _continue(tester); // expenses
    await _continue(tester); // FIRE type
    await _continue(tester); // advanced → save

    expect(saved, hasLength(1));
    expect(saved.single.monthlyExpenses, 75000);
    expect(saved.single.birthYear, DateTime.now().year - 30);
    expect(saved.single.currency, 'INR');
  });

  testWidgets('empty expenses keep the user on the expenses step', (
    tester,
  ) async {
    final saved = await _pumpSetup(tester);

    await _continue(tester); // ages
    await tester.enterText(find.byType(TextFormField), '');
    await _continue(tester);

    expect(find.text('Required'), findsOneWidget);
    expect(find.text('FIRE Type'), findsNothing);
    expect(saved, isEmpty);
  });

  testWidgets('the target age moves above a raised current age', (
    tester,
  ) async {
    await _pumpSetup(tester);

    final currentAgeSlider = find.byType(Slider).first;
    // Drag to the far right: the oldest current age.
    await tester.drag(currentAgeSlider, const Offset(2000, 0));
    await tester.pumpAndSettle();

    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    final current = sliders[0].value;
    final target = sliders[1];
    expect(target.min, current + 1);
    expect(target.value, greaterThanOrEqualTo(target.min));
    expect(target.value, lessThanOrEqualTo(target.max));
    expect(target.max, greaterThan(target.min));
  });

  testWidgets('Coast and Barista FIRE are no longer offered', (tester) async {
    await _pumpSetup(tester);

    await _continue(tester); // ages
    await _continue(tester); // expenses

    expect(find.text('Regular FIRE'), findsOneWidget);
    expect(find.text('Coast FIRE'), findsNothing);
    expect(find.text('Barista FIRE'), findsNothing);
  });
}
