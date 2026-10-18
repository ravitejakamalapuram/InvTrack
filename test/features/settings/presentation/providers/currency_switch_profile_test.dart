// A31: a finished base-currency change is stored on the user's profile so a
// new device restores it.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/connectivity_provider.dart';
import 'package:inv_tracker/core/services/connectivity_service.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';
import 'package:inv_tracker/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:inv_tracker/features/user_profile/presentation/providers/user_profile_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

class _MockConversion extends Mock implements CurrencyConversionService {}

class _MockConnectivity extends Mock implements ConnectivityService {}

class _Repo implements UserProfileRepository {
  _Repo(this.profile);

  UserProfileEntity profile;

  @override
  Future<UserProfileEntity?> getProfile() async => profile;

  @override
  Future<bool> profileExists() async => true;

  @override
  Future<void> saveProfile(UserProfileEntity p) async => profile = p;

  @override
  Future<void> deleteProfile() async {}

  @override
  Stream<UserProfileEntity?> watchProfile() => Stream.value(profile);
}

void main() {
  test(
    'a finished currency switch stores the new currency on the profile',
    () async {
      SharedPreferences.setMockInitialValues({
        'currency': 'USD',
        'locale': 'en_US',
      });
      final prefs = await SharedPreferences.getInstance();
      final conversion = _MockConversion();
      when(conversion.clearCache).thenAnswer((_) async {});
      final connectivity = _MockConnectivity();
      when(connectivity.checkConnectivity).thenAnswer((_) async => true);
      final repo = _Repo(
        UserProfileEntity(
          userId: 'u1',
          preferredCurrency: 'USD',
          preferredLocale: 'en_US',
          countryCode: 'US',
          languageCode: 'en',
          dateFormatPattern: DateFormatPattern.mdy,
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          currencyConversionServiceProvider.overrideWithValue(conversion),
          connectivityServiceProvider.overrideWithValue(connectivity),
          isAuthenticatedProvider.overrideWith((ref) => true),
          allInvestmentsProvider.overrideWith((ref) => Stream.value([])),
          allCashFlowsStreamProvider.overrideWith((ref) => Stream.value([])),
          userProfileProvider.overrideWith((ref) => Stream.value(repo.profile)),
          userProfileRepositoryProvider.overrideWith((ref, id) => repo),
        ],
      );
      addTearDown(container.dispose);
      // Let the profile stream emit so the notifier holds the profile.
      container.listen(userProfileNotifierProvider, (_, _) {});
      await container.read(userProfileProvider.future);
    await Future<void>.delayed(Duration.zero);

      await container
          .read(currencySwitchProvider.notifier)
          .switchCurrencyImmediate('EUR');

      expect(container.read(currencySwitchProvider).isSuccess, isTrue);
      expect(repo.profile.preferredCurrency, 'EUR');
    },
  );
}
