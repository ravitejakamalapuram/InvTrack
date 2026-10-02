import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/auth/presentation/handlers/google_sign_in_handler.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_import_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../mocks/fake_auth_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';

/// The guest's data as a ZIP, held in memory by the merge flow.
final _backupBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2, 3]);

class _FakeExportService extends Fake implements DataExportService {
  int exportCalls = 0;
  final sharedBackups = <Uint8List>[];

  @override
  Future<String> exportAsZip() async {
    exportCalls++;
    return '/cache/InvTrack_Export_1.zip';
  }

  @override
  Future<Uint8List> exportAsZipBytes() async {
    exportCalls++;
    return _backupBytes;
  }

  @override
  Future<void> shareZipBytes(Uint8List bytes) async {
    sharedBackups.add(bytes);
  }
}

class _RecordingImportService extends Fake implements DataImportService {
  _RecordingImportService({this.error});

  final Object? error;
  final calls = <(Uint8List, ImportStrategy)>[];

  @override
  Future<ZipImportResult> importFromZip(
    Uint8List zipBytes,
    ImportStrategy strategy,
  ) async {
    calls.add((zipBytes, strategy));
    if (error != null) throw error!;
    return const ZipImportResult(
      investmentsImported: 2,
      cashflowsImported: 5,
      goalsImported: 1,
      documentsImported: 0,
    );
  }
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
  late Map<String, _RecordingImportService> importersByUid;
  Object? importError;
  bool? handlerResult;

  setUp(() {
    authRepo = FakeAuthRepository(guestUser);
    analytics = FakeAnalyticsService();
    exportService = _FakeExportService();
    importersByUid = {};
    importError = null;
    handlerResult = null;
  });

  Future<void> pumpAndStartBackupMerge(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          analyticsServiceProvider.overrideWithValue(analytics),
          googleSignInInitializedProvider.overrideWith((ref) async {}),
          dataExportServiceProvider.overrideWith((ref) => exportService),
          // One import service per signed-in user, like the real provider,
          // so the test can tell which account the backup was imported into.
          dataImportServiceProvider.overrideWith((ref) {
            final user = ref.watch(authStateProvider).value;
            if (user == null) return null;
            return importersByUid.putIfAbsent(
              user.id,
              () => _RecordingImportService(error: importError),
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
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(handlerResult, isFalse);
    },
  );

  testWidgets(
    'on Google sign-in the in-memory backup is merged into the Google '
    'account automatically, without an "Import now" route',
    (tester) async {
      authRepo.onSignInWithGoogle = () async {
        authRepo.emit(googleUser); // Firebase reports the new session
        return googleUser;
      };

      await pumpAndStartBackupMerge(tester);

      final googleImports = importersByUid[googleUser.id]?.calls ?? [];
      expect(googleImports, hasLength(1));
      expect(googleImports.single.$1, _backupBytes);
      expect(googleImports.single.$2, ImportStrategy.merge);
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
      expect(exportService.sharedBackups, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Share backup'));
      await tester.pumpAndSettle();

      expect(exportService.sharedBackups, [_backupBytes]);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
