// The danger zone's amber icons, measured on the real Data and account screen
// as a guest: the Delete guest data tile and the Replace option of the ZIP
// import dialog. In light mode each icon takes the deeper amber and keeps the
// bright amber for its 15% disc; swapping the two, or dropping the disc's
// colour, puts the icon back at about 2:1 on its disc.
//
// The ids in the test names are rows of test/core/theme/contrast_pairs.dart;
// the guard finds them here.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';
import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:inv_tracker/features/settings/presentation/screens/data_management_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/contrast.dart';
import '../../../../mocks/mock_analytics_service.dart';

class _MockDeletionRequestService extends Mock
    implements DeletionRequestService {}

class _NoGuestBackups extends Fake implements GuestBackupStore {
  @override
  Future<List<String>> list({required String ownerId}) async => const [];

  @override
  Future<String> save(Uint8List bytes, {required String ownerId}) =>
      throw UnimplementedError();
}

const _guest = UserEntity(id: 'guest-1', email: '', isAnonymous: true);

Future<void> _pumpScreen(WidgetTester tester, Brightness brightness) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final requests = _MockDeletionRequestService();
  // No request yet, so the deletion banner stays hidden.
  when(
    () => requests.watchStatus(),
  ).thenAnswer((_) => Stream.value(DeletionRequestStatus.none));

  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_guest)),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        deletionRequestServiceProvider.overrideWithValue(requests),
        guestBackupStoreProvider.overrideWithValue(_NoGuestBackups()),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DataManagementScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The colours of the painted boxes around [icon], nearest first: the disc,
/// then whatever else the tree paints behind it.
List<Color> _boxes(WidgetTester tester, IconData icon) => [
  for (final c in tester.widgetList<Container>(
    find.ancestor(of: find.byIcon(icon), matching: find.byType(Container)),
  ))
    if (c.decoration case BoxDecoration(:final color?)) color,
];

Color _iconColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color!;

/// The colour an `AlertDialog` paints under its content.
Color _dialogGround(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first,
    )
    .color!;

Future<void> _openImportDialog(WidgetTester tester) async {
  await tester.tap(find.text('Import from ZIP'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final en = AppLocalizationsEn();

  testWidgets('settings-tile-warning-icon-light@tint15: the Delete guest data '
      'icon is the deeper amber on a disc of the bright amber', (tester) async {
    await _pumpScreen(tester, Brightness.light);

    const icon = Icons.person_remove_outlined;
    expect(_iconColor(tester, icon), AppColors.warningTextLight);
    final boxes = _boxes(tester, icon);
    expect(boxes.first, AppColors.warningLight.withValues(alpha: 0.15));
    // The section card the tile sits on: the first opaque box behind the disc.
    final card = boxes.firstWhere((c) => c.a == 1.0);
    expect(
      contrastRatio(AppColors.warningTextLight, composeOver(boxes.first, card)),
      greaterThanOrEqualTo(kMinGraphic),
      reason: 'settings-tile-warning-icon-light@tint15',
    );
    // The tile is titled: colour is not the only carrier.
    expect(find.text(en.deleteGuestData), findsOneWidget);
  });

  testWidgets('import-option-warning-icon-light@tint15: the Replace icon is '
      'the deeper amber on a disc of the bright amber', (tester) async {
    await _pumpScreen(tester, Brightness.light);
    await _openImportDialog(tester);

    const icon = Icons.swap_horiz_rounded;
    expect(_iconColor(tester, icon), AppColors.warningTextLight);
    final disc = _boxes(tester, icon).single;
    expect(disc, AppColors.warningLight.withValues(alpha: 0.15));
    expect(
      contrastRatio(
        AppColors.warningTextLight,
        composeOver(disc, _dialogGround(tester)),
      ),
      greaterThanOrEqualTo(kMinGraphic),
      reason: 'import-option-warning-icon-light@tint15',
    );
    // The option is titled and described: colour is not the only carrier.
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Delete existing data first'), findsOneWidget);
  });

  testWidgets('dark mode keeps the dark amber on both the icon and the disc', (
    tester,
  ) async {
    await _pumpScreen(tester, Brightness.dark);
    const deleteIcon = Icons.person_remove_outlined;
    expect(_iconColor(tester, deleteIcon), AppColors.warningDark);
    expect(
      _boxes(tester, deleteIcon).first,
      AppColors.warningDark.withValues(alpha: 0.15),
    );

    await _openImportDialog(tester);
    const replaceIcon = Icons.swap_horiz_rounded;
    expect(_iconColor(tester, replaceIcon), AppColors.warningDark);
    expect(
      _boxes(tester, replaceIcon).single,
      AppColors.warningDark.withValues(alpha: 0.15),
    );
  });
}
