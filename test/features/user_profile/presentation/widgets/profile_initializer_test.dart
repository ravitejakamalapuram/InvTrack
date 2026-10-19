// A31: the base currency is proposed from the phone's country on a first run,
// stored on the user's profile, and restored on a new device.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';
import 'package:inv_tracker/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:inv_tracker/features/user_profile/presentation/providers/user_profile_provider.dart';
import 'package:inv_tracker/features/user_profile/presentation/widgets/profile_initializer.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../investment/data/repositories/mock_investment_repository.dart';

class _FakeProfileRepository implements UserProfileRepository {
  _FakeProfileRepository();

  UserProfileEntity? profile;

  @override
  Future<UserProfileEntity?> getProfile() async => profile;

  @override
  Future<bool> profileExists() async => profile != null;

  @override
  Future<void> saveProfile(UserProfileEntity p) async => profile = p;

  @override
  Future<void> deleteProfile() async => profile = null;

  @override
  Stream<UserProfileEntity?> watchProfile() => Stream.value(profile);
}

void main() {
  const user = UserEntity(id: 'u1', email: 'a@b.c');

  UserProfileEntity stored(String currency) => UserProfileEntity(
    userId: 'u1',
    preferredCurrency: currency,
    preferredLocale: 'en_US',
    countryCode: 'US',
    languageCode: 'en',
    dateFormatPattern: DateFormatPattern.mdy,
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );

  late _FakeProfileRepository repo;
  late FakeInvestmentRepository investments;
  late SharedPreferences prefs;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required ui.Locale locale,
    bool flagOn = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          userProfileRepositoryProvider.overrideWith((ref, id) => repo),
          investmentRepositoryProvider.overrideWithValue(investments),
          deviceLocaleProvider.overrideWithValue(locale),
          securityProvider.overrideWith(_UnlockedSecurity.new),
          analyticsServiceProvider.overrideWithValue(_NoAnalytics()),
          currencyConversionServiceProvider.overrideWithValue(null),
          isBaseCurrencyPromptEnabledProvider.overrideWithValue(flagOn),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProfileInitializer(child: Text('home')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.text('home')));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = _FakeProfileRepository();
    investments = FakeInvestmentRepository();
  });

  testWidgets('a first run on a US phone proposes USD and stores the choice '
      'on the profile only after confirmation', (tester) async {
    final container = await pump(tester, locale: const ui.Locale('en', 'US'));

    expect(find.textContaining('USD'), findsWidgets);
    expect(repo.profile, isNull, reason: 'nothing stored before confirming');

    await tester.tap(find.text('Use USD'));
    await tester.pumpAndSettle();

    expect(repo.profile!.preferredCurrency, 'USD');
    expect(container.read(settingsProvider).currency, 'USD');
  });

  testWidgets('with the flag off nothing is asked, read or stored', (
    tester,
  ) async {
    investments.seed(investments: [_investment()]);
    final container = await pump(
      tester,
      locale: const ui.Locale('en', 'US'),
      flagOn: false,
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.profile, isNull);
    expect(container.read(settingsProvider).currency, 'INR');
  });

  testWidgets('dismissing the proposal stores nothing and keeps the default', (
    tester,
  ) async {
    final container = await pump(tester, locale: const ui.Locale('en', 'US'));

    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();

    expect(repo.profile, isNull);
    expect(container.read(settingsProvider).currency, 'INR');
  });

  testWidgets('an unknown country proposes nothing and never defaults to USD', (
    tester,
  ) async {
    final container = await pump(tester, locale: const ui.Locale('en', 'XX'));

    expect(find.text('Use USD'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.profile, isNull);
    expect(container.read(settingsProvider).currency, 'INR');
  });

  testWidgets('a new device restores the currency from the profile', (
    tester,
  ) async {
    repo.profile = stored('USD');
    final container = await pump(tester, locale: const ui.Locale('en', 'IN'));

    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(settingsProvider).currency, 'USD');
  });

  testWidgets('a user who already has data keeps their currency, even on a US '
      'phone, and it is stored on the profile', (tester) async {
    investments.seed(investments: [_investment()]);
    final container = await pump(tester, locale: const ui.Locale('en', 'US'));

    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(settingsProvider).currency, 'INR');
    expect(repo.profile!.preferredCurrency, 'INR');
  });

  testWidgets('a device with data in another currency is not switched to the '
      'profile currency', (tester) async {
    repo.profile = stored('USD');
    investments.seed(investments: [_investment()]);
    final container = await pump(tester, locale: const ui.Locale('en', 'US'));

    expect(container.read(settingsProvider).currency, 'INR');
    expect(repo.profile!.preferredCurrency, 'USD');
  });

  testWidgets(
    'data that is only on the server (empty local cache) still counts '
    'as data, so no currency is proposed over it',
    (tester) async {
      investments = _ServerOnlyInvestments()
        ..seed(investments: [_investment()]);
      final container = await pump(tester, locale: const ui.Locale('en', 'US'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(settingsProvider).currency, 'INR');
      expect(repo.profile!.preferredCurrency, 'INR');
    },
  );

  testWidgets('an unreachable server defers the decision instead of treating '
      'the account as empty', (tester) async {
    investments = _OfflineInvestments();
    final container = await pump(tester, locale: const ui.Locale('en', 'US'));

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.profile, isNull);
    expect(container.read(settingsProvider).currency, 'INR');
  });

  testWidgets('a phone with no country neither proposes a currency nor stores '
      'US as the country', (tester) async {
    final empty = await pump(tester, locale: const ui.Locale('en'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.profile, isNull);
    expect(empty.read(settingsProvider).currency, 'INR');
  });

  testWidgets('a user with data on a phone with no country is saved without a '
      'made-up US country', (tester) async {
    investments.seed(investments: [_investment()]);
    await pump(tester, locale: const ui.Locale('en'));

    expect(repo.profile!.preferredCurrency, 'INR');
    expect(repo.profile!.countryCode, isNot('US'));
  });

  testWidgets('a currency left on the phone by another account is not taken as '
      'this user\'s choice: a new user is asked', (tester) async {
    SharedPreferences.setMockInitialValues({'currency': 'EUR'});
    prefs = await SharedPreferences.getInstance();
    final container = await pump(tester, locale: const ui.Locale('en', 'US'));

    expect(find.text('Use USD'), findsOneWidget);
    expect(repo.profile, isNull, reason: 'nothing stored before confirming');
    expect(container.read(settingsProvider).currency, 'EUR');
  });

  testWidgets('a currency left on the phone by another account does not hide '
      'this user\'s profile currency', (tester) async {
    SharedPreferences.setMockInitialValues({'currency': 'EUR'});
    prefs = await SharedPreferences.getInstance();
    repo.profile = stored('USD');
    final container = await pump(tester, locale: const ui.Locale('en', 'IN'));

    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(settingsProvider).currency, 'USD');
  });

  testWidgets('a currency chosen while the server check is pending is not '
      'overwritten by the profile read before it', (tester) async {
    repo.profile = stored('USD');
    final gate = Completer<void>();
    investments = _GatedInvestments(gate.future);
    final container = await pump(tester, locale: const ui.Locale('en', 'IN'));

    // The user switches to EUR (and it is stored) while the check is pending.
    repo.profile = stored('EUR');
    await container.read(settingsProvider.notifier).setCurrency('EUR');
    gate.complete();
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).currency, 'EUR');
  });

  testWidgets('the Choose another list shows translated currency names', (
    tester,
  ) async {
    await pump(tester, locale: const ui.Locale('en', 'US'));

    await tester.tap(find.text('Choose another'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(SimpleDialog)));
    expect(find.text(l10n.currencyEUR), findsOneWidget);
    expect(find.text(l10n.currencyAED), findsOneWidget);
    expect(find.text(l10n.currencySAR), findsOneWidget);
  });
}

/// Server has the data but this phone's local cache is still empty.
class _ServerOnlyInvestments extends FakeInvestmentRepository {
  @override
  Future<List<InvestmentEntity>> getAllInvestments() async => [];
}

class _OfflineInvestments extends FakeInvestmentRepository {
  @override
  Future<bool> hasAnyInvestmentOnServer() async => throw StateError('offline');
}

class _GatedInvestments extends FakeInvestmentRepository {
  _GatedInvestments(this._gate);

  final Future<void> _gate;

  @override
  Future<bool> hasAnyInvestmentOnServer() async {
    await _gate;
    return false;
  }
}

class _NoAnalytics extends Mock implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

class _UnlockedSecurity extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState(hasPin: false, isLocked: false);
}

InvestmentEntity _investment() => InvestmentEntity(
  id: 'inv-1',
  name: 'FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2026, 10, 2),
  currency: 'INR',
);
