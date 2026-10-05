import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/connectivity_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/data/services/guest_merge_journal.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/auth/presentation/widgets/pending_guest_backup_notice.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_import_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_auth_repository.dart';
import '../../../../mocks/fake_guest_merge.dart';
import '../../../../mocks/mock_analytics_service.dart';

const _google1 = UserEntity(id: 'google1', email: 'existing@example.com');

const _title = 'Add your guest data to this account?';
const _message =
    'A backup of the investments, cash flows and goals you added as a guest '
    'is saved on this device, and some or all of it is not in this account '
    'yet. Import it now, share it to keep a copy, or keep it on this device. '
    'You can share or delete it later in Settings > Data & Account.';
const _incomplete =
    'Not all of your guest data could be added, for example an investment '
    'or goal whose name this account already uses. The backup stays on this '
    'device until you delete it in Settings > Data & Account.';

class _Security extends SecurityNotifier {
  _Security(this._locked);

  final bool _locked;

  @override
  SecurityState build() => SecurityState(isLocked: _locked);

  void unlock() => state = const SecurityState();
}

void main() {
  late SharedPreferences prefs;
  late InMemoryGuestBackupStore store;
  late RecordingGuestImportService importer;
  late FakeGuestExportService exportService;
  late String backupPath;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = InMemoryGuestBackupStore();
    importer = RecordingGuestImportService();
    exportService = FakeGuestExportService();
    // The process died after the guest's backup was saved and the Google
    // sign-in went through, before the backup was handed over.
    backupPath = await store.save(guestBackupBytes, ownerId: 'guest1');
    await GuestMergeJournal(prefs).begin(
      guestId: 'guest1',
      backupPath: backupPath,
      summary: const GuestBackupSummary(
        investments: 2,
        cashFlows: 5,
        goals: 1,
        documents: 0,
        hasFireSettings: false,
        baseCurrency: 'INR',
      ),
    );
  });

  /// Starts the app signed in to the Google account.
  Future<void> launch(WidgetTester tester, {bool locked = false}) async {
    // A new ProviderScope, like a new process.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(_google1),
          ),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          currencyCodeProvider.overrideWith((ref) => 'INR'),
          securityProvider.overrideWith(() => _Security(locked)),
          dataExportServiceProvider.overrideWith((ref) => exportService),
          guestBackupStoreProvider.overrideWithValue(store),
          guestBackupReaderProvider.overrideWithValue(
            (path) async => store.files[path]!,
          ),
          dataImportServiceProvider.overrideWith((ref) => importer),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => PendingGuestBackupNotice(child: child!),
          home: const Scaffold(body: Text('Home')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<List<String>> googleBackups() => store.list(ownerId: 'google1');

  testWidgets('offers the backup once, with Import now, Share and Keep', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);

    expect(find.text(_title), findsOneWidget);
    expect(find.text(_message), findsOneWidget);
    for (final label in ['Import now', 'Share', 'Keep']) {
      expect(
        tester.getSemantics(
          find.ancestor(
            of: find.text(label),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        ),
        containsSemantics(label: label, isButton: true),
      );
    }
    expect(await googleBackups(), hasLength(1));

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(await googleBackups(), hasLength(1));
    expect(importer.calls, isEmpty);

    await launch(tester);
    expect(find.text(_title), findsNothing);
    semantics.dispose();
  });

  testWidgets('Import now adds the guest data and deletes the backup', (
    tester,
  ) async {
    await launch(tester);

    await tester.tap(find.text('Import now'));
    await tester.pumpAndSettle();

    expect(importer.calls, hasLength(1));
    expect(
      find.text('Your guest data has been added to your Google account.'),
      findsOneWidget,
    );
    expect(await googleBackups(), isEmpty);
  });

  testWidgets('Import now that cannot add everything keeps the backup and '
      'says so', (tester) async {
    importer.result = incompleteGuestImport;
    await launch(tester);

    await tester.tap(find.text('Import now'));
    await tester.pumpAndSettle();

    expect(find.text(_incomplete), findsOneWidget);
    expect(await googleBackups(), hasLength(1));

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await launch(tester);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('an import that fails keeps the backup and offers it again on '
      'the next launch', (tester) async {
    importer.error = StateError('import stopped');
    await launch(tester);

    await tester.tap(find.text('Import now'));
    await tester.pumpAndSettle();
    expect(await googleBackups(), hasLength(1));

    await launch(tester);
    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('Share opens the share sheet and keeps the backup', (
    tester,
  ) async {
    await launch(tester);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(exportService.sharedFiles, [await googleBackups()]);
    expect(await googleBackups(), hasLength(1));
    expect(find.text(_title), findsNothing);
  });

  testWidgets('waits until the app is unlocked', (tester) async {
    await launch(tester, locked: true);
    expect(find.text(_title), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.text('Home')),
    );
    (container.read(securityProvider.notifier) as _Security).unlock();
    await tester.pumpAndSettle();

    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('InvTrackerApp mounts the notice', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          securityProvider.overrideWith(() => _Security(false)),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          routerProvider.overrideWithValue(
            GoRouter(
              navigatorKey: rootNavigatorKey,
              routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
            ),
          ),
          connectivityStatusProvider.overrideWith((ref) => Stream.value(true)),
          currencyConversionServiceProvider.overrideWithValue(null),
          allInvestmentsProvider.overrideWith((ref) => Stream.value([])),
          allCashFlowsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const InvTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PendingGuestBackupNotice), findsOneWidget);
  });
}
