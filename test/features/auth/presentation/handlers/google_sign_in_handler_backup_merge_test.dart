import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:inv_tracker/features/auth/presentation/handlers/google_sign_in_handler.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_import_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fire_number/data/repositories/mock_fire_settings_repository.dart';
import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

import '../../../../mocks/fake_auth_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';

/// The guest's data as a ZIP, as built by the merge flow.
final _backupBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2, 3]);

/// An import that added every record in the guest backup.
const _completeImport = ZipImportResult(
  investmentsImported: 2,
  cashflowsImported: 5,
  goalsImported: 1,
  documentsImported: 0,
);

const _importFailedMessage =
    'You are now signed in with Google, but not all of your guest data could '
    'be added to that account, for example an investment or goal whose name '
    'it already uses. A backup of your guest investments, cash flows and '
    'goals is kept on this device until you delete it in Settings > Data & '
    'Account. Share it to save it '
    'somewhere safe. To add the rest, rename those items in your Google '
    'account, share the backup to your files and import it from Settings > '
    'Data & Account.';

const _detailsWillNotMoveMessage =
    'Your investments, cash flows and goals will be added to your Google '
    'account, but some things cannot be moved yet: investments with no cash '
    'flows and their documents, maturity dates, interest rates, payout '
    'frequency, notes and similar fields, and expected payouts. They are not '
    'in the backup either, so they will be lost. Reminders for those '
    'investments stay off until you add the details again. To keep them, '
    'cancel and add a cash flow or write them down first.';

const _detailsNotMovedMessage =
    'Your investments, cash flows and goals are now in your Google account. '
    'Investments with no cash flows and their documents, maturity dates, '
    'interest rates, payout frequency, notes and similar fields, and '
    'expected payouts were not moved. Reminders for those investments stay '
    'off until you add the details again.';

/// In-memory stand-in for the app-private backup folder.
class _FakeBackupStore implements GuestBackupStore {
  final files = <String, Uint8List>{};

  /// Owner user id of each file in [files].
  final owners = <String, String>{};
  var _next = 0;

  String _path(String ownerId, String name) =>
      '/data/app/files/guest_backups/$ownerId/$name';

  @override
  Future<String> save(Uint8List bytes, {required String ownerId}) async {
    final path = _path(ownerId, 'backup_${_next++}.zip');
    files[path] = bytes;
    owners[path] = ownerId;
    return path;
  }

  @override
  Future<String> transfer(String filePath, {required String toOwnerId}) async {
    final moved = _path(toOwnerId, filePath.split('/').last);
    files[moved] = files.remove(filePath)!;
    owners.remove(filePath);
    owners[moved] = toOwnerId;
    return moved;
  }

  @override
  Future<List<String>> list({required String ownerId}) async => [
    for (final MapEntry(:key, :value) in owners.entries)
      if (value == ownerId) key,
  ];

  @override
  Future<void> delete(String filePath) async {
    files.remove(filePath);
    owners.remove(filePath);
  }

  @override
  Future<void> deleteAll({required String ownerId}) async {
    for (final path in await list(ownerId: ownerId)) {
      await delete(path);
    }
  }
}

class _FakeExportService extends Fake implements DataExportService {
  int exportCalls = 0;
  final sharedFiles = <List<String>>[];

  /// Replaces the default in-memory backup when set.
  ZipExport? export;

  @override
  Future<String> exportAsZip() async {
    exportCalls++;
    return '/cache/InvTrack_Export_1.zip';
  }

  @override
  Future<ZipExport> exportAsZipBytes() async {
    exportCalls++;
    return export ??
        ZipExport(
          bytes: _backupBytes,
          investments: _completeImport.investmentsImported,
          cashFlows: _completeImport.cashflowsImported,
          goals: _completeImport.goalsImported,
          documents: _completeImport.documentsImported,
          hasFireSettings: false,
          investmentsWithDetailsNotInExport: 0,
          investmentsNotInExport: 0,
          expectedCashFlows: 0,
        );
  }

  @override
  Future<void> shareZipFiles(List<String> filePaths) async {
    sharedFiles.add(filePaths);
  }
}

class _RecordingImportService extends Fake implements DataImportService {
  _RecordingImportService({this.error, this.result = _completeImport});

  final Object? error;
  final ZipImportResult result;
  final calls = <(Uint8List, ImportStrategy, String)>[];

  @override
  Future<ZipImportResult> importFromZip(
    Uint8List zipBytes,
    ImportStrategy strategy, {
    required String baseCurrency,
  }) async {
    calls.add((zipBytes, strategy, baseCurrency));
    if (error != null) throw error!;
    return result;
  }
}

class _MockDocumentRepository extends Mock implements DocumentRepository {}

class _MockDocumentStorageService extends Mock
    implements DocumentStorageService {}

/// Runs the tracked operation without measuring it.
class _PassThroughPerformanceService extends Fake
    implements PerformanceService {
  @override
  Future<T> trackOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, int>? metrics,
    Map<String, String>? attributes,
  }) => operation();
}

class _LinkButton extends ConsumerWidget {
  const _LinkButton({required this.onResult});

  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final handler = GoogleSignInHandler(ref: ref, context: context);
            onResult(await handler.handleSignIn());
          },
          child: const Text('Link'),
        ),
      ),
    );
  }
}

void main() {
  late FakeAuthRepository authRepo;
  late FakeAnalyticsService analytics;
  late _FakeExportService exportService;
  late _FakeBackupStore backupStore;
  late Map<String, _RecordingImportService> importersByUid;
  Object? importError;
  ZipImportResult importResult = _completeImport;
  DataImportService? googleImportService;
  bool? handlerResult;

  setUp(() {
    authRepo = FakeAuthRepository(guestUser);
    analytics = FakeAnalyticsService();
    exportService = _FakeExportService();
    backupStore = _FakeBackupStore();
    importersByUid = {};
    importError = null;
    importResult = _completeImport;
    googleImportService = null;
    handlerResult = null;
  });

  Future<void> pumpAndStartBackupMerge(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          analyticsServiceProvider.overrideWithValue(analytics),
          googleSignInInitializedProvider.overrideWith((ref) async {}),
          currencyCodeProvider.overrideWithValue('EUR'),
          dataExportServiceProvider.overrideWith((ref) => exportService),
          guestBackupStoreProvider.overrideWithValue(backupStore),
          // One import service per signed-in user, like the real provider,
          // so the test can tell which account the backup was imported into.
          dataImportServiceProvider.overrideWith((ref) {
            final user = ref.watch(authStateProvider).value;
            if (user == null) return null;
            if (user.id == googleUser.id && googleImportService != null) {
              return googleImportService;
            }
            return importersByUid.putIfAbsent(
              user.id,
              () => _RecordingImportService(
                error: importError,
                result: importResult,
              ),
            );
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _LinkButton(onResult: (r) => handlerResult = r),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Linking fails because the Google account already exists, so the
    // backup-and-merge dialog opens.
    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
    expect(find.text('Google Account Already Exists'), findsOneWidget);

    await tester.tap(find.text('Backup & Sign In'));
    await tester.pumpAndSettle();
  }

  Iterable<String> eventNames() => analytics.loggedEvents.map((e) => e.name);

  testWidgets(
    'cancelling the Google account picker is a cancel: guest stays signed in, '
    'nothing is imported, no "Import now" prompt and no failure analytics',
    (tester) async {
      authRepo.onSignInWithGoogle = () async => null; // user cancelled

      await pumpAndStartBackupMerge(tester);

      expect(authRepo.signInWithGoogleCalls, 1);
      expect(authRepo.currentUser, guestUser);
      expect(authRepo.signOutCalls, 0);
      expect(eventNames(), isNot(contains('account_link_failure')));
      expect(find.text('Import Now'), findsNothing);
      expect(find.text('Backup Created'), findsNothing);
      expect(
        importersByUid.values.expand((s) => s.calls),
        isEmpty,
        reason: 'nothing may be imported when sign-in was cancelled',
      );
      expect(
        backupStore.files,
        isEmpty,
        reason: 'the guest is still signed in with all of their data',
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(handlerResult, isFalse);
    },
  );

  testWidgets(
    'on Google sign-in the in-memory backup is merged into the Google '
    'account automatically, without an "Import now" route',
    (tester) async {
      Map<String, Uint8List>? savedAtSignIn;
      Map<String, String>? ownersAtSignIn;
      authRepo.onSignInWithGoogle = () async {
        savedAtSignIn = Map.of(backupStore.files);
        ownersAtSignIn = Map.of(backupStore.owners);
        authRepo.emit(googleUser); // Firebase reports the new session
        return googleUser;
      };

      await pumpAndStartBackupMerge(tester);

      expect(
        savedAtSignIn?.values,
        [_backupBytes],
        reason: 'the backup must be on disk before the guest session ends',
      );
      expect(
        ownersAtSignIn?.values,
        [guestUser.id],
        reason: 'until the sign-in, the backup belongs to the guest',
      );
      expect(
        backupStore.files,
        isEmpty,
        reason: 'a full merge needs no leftover copy of the guest data',
      );

      final googleImports = importersByUid[googleUser.id]?.calls ?? [];
      expect(googleImports, hasLength(1));
      expect(googleImports.single.$1, _backupBytes);
      expect(googleImports.single.$2, ImportStrategy.merge);
      expect(
        googleImports.single.$3,
        'EUR',
        reason: "rows without a currency take the guest's base currency",
      );
      expect(
        importersByUid[guestUser.id]?.calls ?? [],
        isEmpty,
        reason: 'the backup must not be imported back into the guest account',
      );

      expect(find.text('Import Now'), findsNothing);
      expect(
        find.text('Your guest data has been added to your Google account.'),
        findsOneWidget,
      );
      final linkFailures = analytics.loggedEvents.where(
        (e) => e.name == 'account_link_failure',
      );
      expect(linkFailures, hasLength(1));
      expect(linkFailures.single.parameters, {
        'reason': 'google_account_exists',
      });
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(handlerResult, isTrue);
    },
  );

  testWidgets(
    'if the import fails after sign-in, the user is offered the backup file '
    'to save somewhere they can see',
    (tester) async {
      importError = Exception('Firestore unavailable');
      authRepo.onSignInWithGoogle = () async {
        authRepo.emit(googleUser);
        return googleUser;
      };

      await pumpAndStartBackupMerge(tester);

      expect(importersByUid[googleUser.id]?.calls, hasLength(1));
      expect(find.text('Save your guest backup'), findsOneWidget);
      expect(find.text(_importFailedMessage), findsOneWidget);
      expect(exportService.sharedFiles, isEmpty);
      expect(backupStore.files.values, [_backupBytes]);
      expect(
        backupStore.owners.values,
        [googleUser.id],
        reason:
            'the kept backup belongs to the Google account it was meant '
            'for, so no other account on the device can see it',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Share backup'));
      await tester.pumpAndSettle();

      expect(exportService.sharedFiles, [backupStore.files.keys.toList()]);
      expect(
        backupStore.files.values,
        [_backupBytes],
        reason: 'sharing does not prove the user saved it',
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'closing the backup prompt keeps the backup on the device, so the only '
    'copy of the guest data outlives the dialog and the process',
    (tester) async {
      importError = Exception('Firestore unavailable');
      authRepo.onSignInWithGoogle = () async {
        authRepo.emit(googleUser);
        return googleUser;
      };

      await pumpAndStartBackupMerge(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();

      expect(find.text('Save your guest backup'), findsNothing);
      expect(exportService.sharedFiles, isEmpty);
      expect(backupStore.files.values, [_backupBytes]);
      expect(handlerResult, isFalse);
    },
  );

  // Merge skips guest records the Google account already has by name, and
  // the export leaves out investments that have no cash flows. Either way
  // the guest account can no longer be reached, so anything short of a full
  // import must offer the backup instead of reporting success.
  final incompleteImports = <String, ZipImportResult>{
    'an investment with the same name already exists': const ZipImportResult(
      investmentsImported: 1,
      cashflowsImported: 3,
      goalsImported: 1,
      documentsImported: 0,
      warnings: ['Skipped "SBI FD" - already exists'],
    ),
    'a document could not be imported': const ZipImportResult(
      investmentsImported: 2,
      cashflowsImported: 5,
      goalsImported: 1,
      documentsImported: 0,
      warnings: ['Failed to import document: bad signature'],
    ),
    'fewer investments were imported than the backup holds':
        const ZipImportResult(
          investmentsImported: 1,
          cashflowsImported: 5,
          goalsImported: 1,
          documentsImported: 0,
        ),
  };

  for (final MapEntry(key: reason, value: result)
      in incompleteImports.entries) {
    testWidgets(
      'when $reason, the merge is not reported as done and the backup is '
      'offered',
      (tester) async {
        importResult = result;
        authRepo.onSignInWithGoogle = () async {
          authRepo.emit(googleUser);
          return googleUser;
        };

        await pumpAndStartBackupMerge(tester);

        expect(importersByUid[googleUser.id]?.calls, hasLength(1));
        expect(
          find.text('Your guest data has been added to your Google account.'),
          findsNothing,
        );
        expect(find.text('Save your guest backup'), findsOneWidget);
        expect(find.text(_importFailedMessage), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Share backup'));
        await tester.pumpAndSettle();

        expect(exportService.sharedFiles, [backupStore.files.keys.toList()]);
        expect(backupStore.files.values, [_backupBytes]);
        expect(handlerResult, isFalse);
      },
    );
  }

  testWidgets(
    'when the Google account already has FIRE settings, the merge keeps '
    'them and offers the backup instead of reporting success',
    (tester) async {
      final accountSettings = FireSettingsEntity(
        id: 'account',
        monthlyExpenses: 200000,
        currentAge: 40,
        targetFireAge: 55,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      final googleFireSettings = FakeFireSettingsRepository()
        ..seed(accountSettings);
      addTearDown(googleFireSettings.dispose);
      googleImportService = DataImportService(
        investmentRepository: FakeInvestmentRepository(),
        goalRepository: FakeGoalRepository(),
        documentRepository: _MockDocumentRepository(),
        documentStorageService: _MockDocumentStorageService(),
        fireSettingsRepository: googleFireSettings,
        performanceService: _PassThroughPerformanceService(),
      );

      final archive = Archive();
      for (final MapEntry(:key, :value) in {
        'metadata.json': '{"version":"1.0","files":[]}',
        'fire_settings.json':
            '{"monthlyExpenses":30000,"currentAge":25,"targetFireAge":45}',
      }.entries) {
        final bytes = utf8.encode(value);
        archive.addFile(ArchiveFile(key, bytes.length, bytes));
      }
      final guestBackup = Uint8List.fromList(ZipEncoder().encode(archive)!);
      exportService.export = ZipExport(
        bytes: guestBackup,
        investments: 0,
        cashFlows: 0,
        goals: 0,
        documents: 0,
        hasFireSettings: true,
        investmentsWithDetailsNotInExport: 0,
        investmentsNotInExport: 0,
        expectedCashFlows: 0,
      );
      authRepo.onSignInWithGoogle = () async {
        authRepo.emit(googleUser);
        return googleUser;
      };

      await pumpAndStartBackupMerge(tester);

      expect(googleFireSettings.settings, same(accountSettings));
      expect(
        find.text('Your guest data has been added to your Google account.'),
        findsNothing,
      );
      expect(find.text('Save your guest backup'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Share backup'));
      await tester.pumpAndSettle();

      expect(exportService.sharedFiles, [backupStore.files.keys.toList()]);
      expect(backupStore.files.values, [guestBackup]);
      expect(handlerResult, isFalse);
    },
  );

  // The backup ZIP carries only name, type, status and cash flows per
  // investment, and no expected cash flows. Those details cannot be recovered
  // once the guest session ends, so the guest must be told before signing in
  // and be able to stop.
  final detailsLeftBehind = <String, ZipExport>{
    'an investment has details the backup cannot carry': ZipExport(
      bytes: _backupBytes,
      investments: 2,
      cashFlows: 5,
      goals: 1,
      documents: 0,
      hasFireSettings: false,
      investmentsWithDetailsNotInExport: 1,
      investmentsNotInExport: 0,
      expectedCashFlows: 0,
    ),
    'the guest has expected cash flows': ZipExport(
      bytes: _backupBytes,
      investments: 2,
      cashFlows: 5,
      goals: 1,
      documents: 0,
      hasFireSettings: false,
      investmentsWithDetailsNotInExport: 0,
      investmentsNotInExport: 0,
      expectedCashFlows: 2,
    ),
    // The backup holds investments only as cash flow rows, so the import
    // adds the other 2 of these 3 and the merge is still complete.
    'an investment has no cash flows': ZipExport(
      bytes: _backupBytes,
      investments: 3,
      cashFlows: 5,
      goals: 1,
      documents: 0,
      hasFireSettings: false,
      investmentsWithDetailsNotInExport: 0,
      investmentsNotInExport: 1,
      expectedCashFlows: 0,
    ),
  };

  for (final MapEntry(key: reason, value: export)
      in detailsLeftBehind.entries) {
    testWidgets(
      'when $reason, the guest is warned before signing in and cancelling '
      'changes nothing',
      (tester) async {
        exportService.export = export;
        authRepo.onSignInWithGoogle = () async {
          authRepo.emit(googleUser);
          return googleUser;
        };

        await pumpAndStartBackupMerge(tester);

        expect(find.text('Some details will not move'), findsOneWidget);
        expect(find.text(_detailsWillNotMoveMessage), findsOneWidget);
        expect(
          authRepo.signInWithGoogleCalls,
          0,
          reason: 'the warning must come before the irreversible sign-in',
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(authRepo.signInWithGoogleCalls, 0);
        expect(authRepo.currentUser, guestUser);
        expect(backupStore.files, isEmpty);
        expect(importersByUid.values.expand((s) => s.calls), isEmpty);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(handlerResult, isFalse);
      },
    );

    testWidgets(
      'when $reason and the guest goes ahead, the merge is reported as '
      'partial without implying the backup holds the lost details',
      (tester) async {
        exportService.export = export;
        authRepo.onSignInWithGoogle = () async {
          authRepo.emit(googleUser);
          return googleUser;
        };

        await pumpAndStartBackupMerge(tester);
        await tester.tap(
          find.widgetWithText(FilledButton, 'Sign in without them'),
        );
        await tester.pumpAndSettle();

        expect(authRepo.signInWithGoogleCalls, 1);
        expect(importersByUid[googleUser.id]?.calls, hasLength(1));
        expect(
          find.text('Your guest data has been added to your Google account.'),
          findsNothing,
        );
        expect(find.text('Some details were not moved'), findsOneWidget);
        expect(find.text(_detailsNotMovedMessage), findsOneWidget);
        expect(find.text('Share backup'), findsNothing);
        expect(
          backupStore.files,
          isEmpty,
          reason:
              'every record the backup holds is in the Google account, so '
              'keeping it would only leave financial data on the device',
        );

        await tester.tap(find.widgetWithText(TextButton, 'OK'));
        await tester.pumpAndSettle();

        expect(find.text('Some details were not moved'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(handlerResult, isFalse);
      },
    );
  }

  testWidgets(
    'if the Google sign-in throws while the guest is still signed in, the '
    'backup is removed so retries do not pile up copies',
    (tester) async {
      authRepo.onSignInWithGoogle = () async =>
          throw Exception('network error');

      await pumpAndStartBackupMerge(tester);

      expect(authRepo.signInWithGoogleCalls, 1);
      expect(authRepo.currentUser, guestUser);
      expect(backupStore.files, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(handlerResult, isFalse);
    },
  );
}
