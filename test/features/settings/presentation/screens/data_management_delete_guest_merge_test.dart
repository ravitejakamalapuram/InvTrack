import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/data/services/guest_merge_journal.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/settings/data/services/account_data_deletion_service.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:inv_tracker/features/settings/presentation/screens/data_management_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_guest_merge.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockDeletionRequestService extends Mock
    implements DeletionRequestService {}

class _MockAccountDataDeletionService extends Mock
    implements AccountDataDeletionService {}

class _MockDocumentStorageService extends Mock
    implements DocumentStorageService {}

class _FakeSharedPreferences extends Fake implements SharedPreferences {}

/// Delete Account on the Data & Account screen when a guest merge into the
/// account did not finish handing its backup over (A79).
void main() {
  const user = UserEntity(id: 'google1', email: 'user@example.com');

  late _MockAuthRepository auth;
  late _MockAccountDataDeletionService dataDeletion;
  late InMemoryGuestBackupStore store;
  late SharedPreferences prefs;

  setUpAll(() {
    registerFallbackValue(() async {});
    registerFallbackValue(_FakeSharedPreferences());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    auth = _MockAuthRepository();
    dataDeletion = _MockAccountDataDeletionService();
    store = InMemoryGuestBackupStore();

    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => auth.deleteAccount()).thenAnswer((_) async {});
    when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async => true);
    // The server wipe is mocked; the local files are deleted for real.
    when(
      () => dataDeletion.deleteEverything(
        deleteLocalFiles: any(named: 'deleteLocalFiles'),
        prefs: any(named: 'prefs'),
      ),
    ).thenAnswer((invocation) async {
      final deleteLocalFiles =
          invocation.namedArguments[#deleteLocalFiles]
              as Future<void> Function();
      await deleteLocalFiles();
    });
  });

  testWidgets('removes a backup still owned by the guest whose merge into '
      'this account did not finish, and what the device kept about it', (
    tester,
  ) async {
    // The merge saved the guest's backup, but the process died before the
    // backup reached this account.
    final guestBackup = await store.save(guestBackupBytes, ownerId: 'guest1');
    await GuestMergeJournal(prefs).begin(
      guestId: 'guest1',
      backupPath: guestBackup,
      summary: const GuestBackupSummary(
        investments: 2,
        cashFlows: 5,
        goals: 1,
        documents: 0,
        hasFireSettings: false,
        baseCurrency: 'INR',
      ),
    );
    final analytics = _MockAnalyticsService();
    when(() => analytics.setUserId(any())).thenAnswer((_) async {});
    final requests = _MockDeletionRequestService();
    when(() => requests.requestDeletion()).thenAnswer((_) async => true);
    when(
      () => requests.requestStatus(),
    ).thenAnswer((_) async => DeletionRequestStatus.confirmed);
    final documents = _MockDocumentStorageService();
    when(() => documents.deleteAllUserDocuments()).thenAnswer((_) async {});

    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          authRepositoryProvider.overrideWithValue(auth),
          googleSignInInitializedProvider.overrideWith((ref) async {}),
          analyticsServiceProvider.overrideWithValue(analytics),
          sharedPreferencesProvider.overrideWithValue(prefs),
          deletionRequestServiceProvider.overrideWithValue(requests),
          accountDataDeletionServiceProvider.overrideWithValue(dataDeletion),
          documentStorageServiceProvider.overrideWithValue(documents),
          guestBackupStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DataManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(DataManagementScreen)),
    );

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.deleteEverything));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.text(l10n.deleteMyAccount));
    await tester.pumpAndSettle();

    expect(find.text('Account deleted successfully'), findsOneWidget);
    expect(store.files, isEmpty);
    expect(prefs.getKeys().where((key) => key.startsWith('guest_')), isEmpty);
  });
}
