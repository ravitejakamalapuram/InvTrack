// A11 (#755, PLAN-07, UX-10, PLAN-06): FIRE settings sheets show why a save
// failed instead of closing silently, parse grouped amounts, and expose the
// inputs that change the FIRE number.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_settings_validator.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_notifier.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/fire_number/presentation/screens/fire_settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _settings = FireSettingsEntity(
  id: 'fire',
  monthlyExpenses: 50000,
  birthYear: DateTime.now().year - 30,
  targetFireAge: 45,
  isSetupComplete: true,
  currency: 'INR',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class _Notifier extends FireSettingsNotifier {
  _Notifier(this.saved, {this.fail = false});

  final List<FireSettingsEntity> saved;
  final bool fail;

  @override
  Future<void> saveSettings(FireSettingsEntity settings) async {
    if (fail) {
      throw FireSettingsValidationException([
        FireSettingsError.targetAgeNotAfterCurrent,
      ]);
    }
    saved.add(settings);
  }
}

Future<List<FireSettingsEntity>> _pump(
  WidgetTester tester, {
  bool fail = false,
  FireSettingsEntity? settings,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final saved = <FireSettingsEntity>[];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currencyCodeProvider.overrideWith((ref) => 'INR'),
        currencySymbolProvider.overrideWith((ref) => '₹'),
        fireSettingsProvider.overrideWith(
          (ref) => Stream.value(settings ?? _settings),
        ),
        fireSettingsNotifierProvider.overrideWith(
          () => _Notifier(saved, fail: fail),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FireSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  testWidgets('a rejected save keeps the sheet open and says why', (
    tester,
  ) async {
    await _pump(tester, fail: true);

    await tester.tap(find.text('Target FIRE Age'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    // The reason comes from the app's strings, not the validator's English.
    expect(
      find.text('Your target FIRE age must be after your current age.'),
      findsOneWidget,
    );
  });

  testWidgets('the target age editor starts above the current age', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Target FIRE Age'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 31);
    expect(slider.max, greaterThan(slider.min));
  });

  testWidgets('grouped monthly expenses are saved as typed', (tester) async {
    final saved = await _pump(tester);

    await tester.tap(find.text('Monthly Expenses'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1,25,000');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saved.single.monthlyExpenses, 125000);
  });

  testWidgets('saving an amount unchanged keeps its paise', (tester) async {
    // ₹1,234.56 opened as "1235" and was saved rounded.
    final saved = await _pump(
      tester,
      settings: _settings.copyWith(monthlyExpenses: 1234.56),
    );

    await tester.tap(find.text('Monthly Expenses'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1234.56',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saved.single.monthlyExpenses, 1234.56);
  });

  testWidgets('a EUR amount typed with a decimal comma keeps its cents', (
    tester,
  ) async {
    // "1500,50" was saved as €150,050.
    final saved = await _pump(
      tester,
      settings: _settings.copyWith(currency: 'EUR', monthlyExpenses: 1234.56),
    );

    await tester.tap(find.text('Monthly Expenses'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1234,56',
    );
    await tester.enterText(find.byType(TextField), '1500,50');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saved.single.monthlyExpenses, 1500.50);
  });

  testWidgets('amounts are grouped the way their currency writes them', (
    tester,
  ) async {
    await _pump(
      tester,
      settings: _settings.copyWith(monthlyExpenses: 1500000, otherAssets: 0),
    );

    expect(find.text('₹15,00,000'), findsOneWidget);
  });

  testWidgets('invalid monthly expenses are not replaced by the old value', (
    tester,
  ) async {
    final saved = await _pump(tester);

    await tester.tap(find.text('Monthly Expenses'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
    expect(find.text('Enter a valid amount'), findsOneWidget);
  });

  testWidgets('other assets and a monthly SIP can be entered', (tester) async {
    final saved = await _pump(tester);

    await tester.tap(find.text('Other assets'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5,00,000');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Monthly SIP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '25000');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saved[0].otherAssets, 500000);
    expect(saved[1].monthlySip, 25000);
    expect(find.text('Healthcare buffer'), findsOneWidget);
    expect(find.text('Emergency fund'), findsOneWidget);
  });
}
