// #998: the FIRE progress card on Overview must not overflow at large text.
// Its header (icon, title, status badge) and its figure row (value, percent,
// target) wrap onto a second line instead of running off the card.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/services/fire_calculation_service.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_providers.dart';
import 'package:inv_tracker/features/fire_number/presentation/widgets/fire_dashboard_card.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _settings = FireSettingsEntity(
  id: 'fire',
  monthlyExpenses: 50000,
  birthYear: 1998,
  targetFireAge: 50,
  isSetupComplete: true,
  currency: 'INR',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('progress card fits 360dp at text x$scale', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final result = FireCalculationService().calculate(
        settings: _settings,
        currentPortfolioValue: 12345678,
        currentMonthlySavings: 40000,
        asOf: DateTime(2026, 10, 2),
        inputs: const FireInputsSummary(
          investmentsValue: 12345678,
          principalWithoutValue: 0,
          otherAssets: 0,
          savingsSource: MonthlySavingsSource.history,
        ),
      );
      tester.view
        ..physicalSize = const Size(360 * 3, 800 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currencyCodeProvider.overrideWith((ref) => 'INR'),
            currencySymbolProvider.overrideWith((ref) => '₹'),
            currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
            fireSettingsProvider.overrideWith((ref) => Stream.value(_settings)),
            fireCalculationProvider.overrideWithValue(AsyncValue.data(result)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: FireDashboardCard(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
