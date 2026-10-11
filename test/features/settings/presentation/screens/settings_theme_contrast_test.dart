// Settings tiles, their snackbars and the notices on the Data & Account screen
// paint the status colours of the theme they are in. In dark the light green,
// red and amber lose their contrast on the dark card once the light values
// deepen, so the tiles read the dark values there.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/deletion_request_status_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/security_settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/deletion_request_banner.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/saved_guest_backup_tile.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/contrast.dart';
import '../../../../mocks/fake_auth_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';

class _MockCrashlyticsService extends Mock implements CrashlyticsService {}

class _Pin extends SecurityNotifier {
  _Pin(this.hasPin);
  final bool hasPin;

  @override
  SecurityState build() => SecurityState(hasPin: hasPin);
}

/// A currency switch the test can finish by hand.
class _Switch extends CurrencySwitch {
  @override
  CurrencySwitchStatus build() => const CurrencySwitchStatus.idle();

  void succeed() =>
      state = const CurrencySwitchStatus.success(targetCurrency: 'USD');
}

class _OneBackup extends Fake implements GuestBackupStore {
  @override
  Future<List<String>> list({required String ownerId}) async => const [
    '/data/app/files/guest_backups/InvTrack_Guest_Backup_1.zip',
  ];

  @override
  Future<String> save(Uint8List bytes, {required String ownerId}) =>
      throw UnimplementedError();
}

class _NoDeletionService extends Fake implements DeletionRequestService {}

const _user = UserEntity(id: 'uid-1', email: 'a@b.c');

Widget _app(ThemeData theme, Widget home, List<Override> overrides) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

Color _icon(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Security settings, app lock on', () {
    Future<void> pump(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        _app(theme, const SecuritySettingsScreen(), [
          securityProvider.overrideWith(() => _Pin(true)),
        ]),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('in dark: the lock icon is the dark green', (tester) async {
      await pump(tester, AppTheme.darkTheme);
      expect(_icon(tester, Icons.lock), AppColors.successDark);
      expect(
        contrastRatio(AppColors.successDark, AppColors.cardDark),
        greaterThanOrEqualTo(kMinGraphic),
      );
    });

    testWidgets('in light: unchanged, the light green', (tester) async {
      await pump(tester, AppTheme.lightTheme);
      expect(_icon(tester, Icons.lock), AppColors.successLight);
    });
  });

  group('Settings screen', () {
    late SharedPreferences prefs;

    Future<ProviderContainer> pump(WidgetTester tester, ThemeData theme) async {
      SharedPreferences.setMockInitialValues({'currency': 'INR'});
      prefs = await SharedPreferences.getInstance();
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(theme, const SettingsScreen(), [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(googleUser),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          securityProvider.overrideWith(() => _Pin(false)),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          crashlyticsServiceProvider.overrideWithValue(
            _MockCrashlyticsService(),
          ),
          googleSignInInitializedProvider.overrideWith((ref) async {}),
          currencySwitchProvider.overrideWith(_Switch.new),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 500));
      return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    }

    testWidgets('in dark: Sign Out is the dark red, Currency the dark green', (
      tester,
    ) async {
      await pump(tester, AppTheme.darkTheme);

      expect(_icon(tester, Icons.logout), AppColors.errorDark);
      expect(
        _icon(tester, Icons.currency_exchange_rounded),
        AppColors.successDark,
      );
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('in light: unchanged', (tester) async {
      await pump(tester, AppTheme.lightTheme);

      expect(_icon(tester, Icons.logout), AppColors.errorLight);
      expect(
        _icon(tester, Icons.currency_exchange_rounded),
        AppColors.successLight,
      );
    });

    for (final dark in [true, false]) {
      testWidgets(
        'the currency-changed snackbar has the ${dark ? 'dark' : 'light'} '
        'green fill and a label that reads on it',
        (tester) async {
          final container = await pump(
            tester,
            dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          );
          (container.read(currencySwitchProvider.notifier) as _Switch)
              .succeed();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          final bar = tester.widget<SnackBar>(find.byType(SnackBar));
          final fill = dark ? AppColors.successDark : AppColors.successLight;
          expect(bar.backgroundColor, fill);
          final label = find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('USD'),
          );
          expect(label, findsOneWidget);
          final labelColor = DefaultTextStyle.of(
            tester.element(label),
          ).style.color!;
          if (dark) {
            expect(
              contrastRatio(labelColor, fill),
              greaterThanOrEqualTo(kMinText),
            );
          }
          // Let the screen's reset timer run out.
          await tester.pump(const Duration(seconds: 3));
        },
      );
    }
  });

  group('Saved guest backup tile', () {
    Future<void> pump(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        _app(theme, const Scaffold(body: SavedGuestBackupTile()), [
          authStateProvider.overrideWith((ref) => Stream.value(_user)),
          guestBackupStoreProvider.overrideWithValue(_OneBackup()),
        ]),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('in dark: the icon is the dark amber', (tester) async {
      await pump(tester, AppTheme.darkTheme);
      expect(_icon(tester, Icons.restore_page), AppColors.warningDark);
    });

    testWidgets('in light: unchanged, the light amber', (tester) async {
      await pump(tester, AppTheme.lightTheme);
      expect(_icon(tester, Icons.restore_page), AppColors.warningLight);
    });
  });

  group('Deletion request banner', () {
    Future<void> pump(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        _app(theme, const Scaffold(body: DeletionRequestBanner()), [
          deletionRequestStatusProvider.overrideWith(
            (ref) => Stream.value(DeletionRequestStatus.confirmed),
          ),
          deletionRequestServiceProvider.overrideWithValue(
            _NoDeletionService(),
          ),
        ]),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('in dark: the warning icon is the dark red', (tester) async {
      await pump(tester, AppTheme.darkTheme);
      expect(_icon(tester, Icons.warning_amber), AppColors.errorDark);
      expect(
        find.text('Your account is scheduled for deletion.'),
        findsOneWidget,
      );
    });

    testWidgets('in light: unchanged, the light red', (tester) async {
      await pump(tester, AppTheme.lightTheme);
      expect(_icon(tester, Icons.warning_amber), AppColors.errorLight);
    });
  });
}
