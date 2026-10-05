/// A78: "Delete Guest Data" must follow the same safe order as Delete
/// Account: nothing is wiped until the server holds `deletionRequests/{uid}`,
/// and every outcome is reported truthfully.
library;

import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/settings/data/services/account_data_deletion_service.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:inv_tracker/features/settings/presentation/screens/data_management_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDeletionRequestService extends Mock
    implements DeletionRequestService {}

class MockAccountDataDeletionService extends Mock
    implements AccountDataDeletionService {}

class MockDocumentStorageService extends Mock
    implements DocumentStorageService {}

class FakeSharedPreferences extends Fake implements SharedPreferences {}

class _NoGuestBackups extends Fake implements GuestBackupStore {
  @override
  Future<List<String>> list({required String ownerId}) async => const [];

  @override
  Future<String> save(Uint8List bytes, {required String ownerId}) =>
      throw UnimplementedError();
}

void main() {
  const guest = UserEntity(id: 'guest-1', email: '', isAnonymous: true);
  final en = AppLocalizationsEn();

  late MockAuthRepository auth;
  late FakeAnalyticsService analytics;
  late MockDeletionRequestService requests;
  late MockAccountDataDeletionService dataDeletion;
  late SharedPreferences prefs;
  late List<String> calls;

  setUpAll(() {
    registerFallbackValue(() async {});
    registerFallbackValue(FakeSharedPreferences());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    auth = MockAuthRepository();
    analytics = FakeAnalyticsService();
    requests = MockDeletionRequestService();
    dataDeletion = MockAccountDataDeletionService();
    calls = [];

    // A guest signed in long ago: Google re-auth must never be offered.
    when(() => auth.lastSignInTime).thenReturn(DateTime.utc(2026, 1, 1));
    when(() => auth.signOut()).thenAnswer((_) async => calls.add('signOut'));
    when(
      () => auth.deleteAccount(),
    ).thenAnswer((_) async => calls.add('deleteAuth'));
    when(() => auth.reauthenticateWithGoogle()).thenAnswer((_) async {
      calls.add('reauth');
      return true;
    });
    when(() => requests.requestDeletion()).thenAnswer((_) async {
      calls.add('request');
      return true;
    });
    when(
      () => requests.requestStatus(),
    ).thenAnswer((_) async => DeletionRequestStatus.confirmed);
    when(() => requests.withdraw()).thenAnswer((_) async {
      calls.add('withdraw');
      return true;
    });
    when(
      () => dataDeletion.deleteEverything(
        deleteLocalFiles: any(named: 'deleteLocalFiles'),
        prefs: any(named: 'prefs'),
      ),
    ).thenAnswer((_) async => calls.add('wipe'));
  });

  Future<void> deleteGuestData(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(guest)),
          authRepositoryProvider.overrideWithValue(auth),
          googleSignInInitializedProvider.overrideWith(
            (ref) async => calls.add('init'),
          ),
          analyticsServiceProvider.overrideWithValue(analytics),
          sharedPreferencesProvider.overrideWithValue(prefs),
          deletionRequestServiceProvider.overrideWithValue(requests),
          accountDataDeletionServiceProvider.overrideWithValue(dataDeletion),
          documentStorageServiceProvider.overrideWithValue(
            MockDocumentStorageService(),
          ),
          guestBackupStoreProvider.overrideWithValue(_NoGuestBackups()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DataManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(en.deleteGuestData));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, en.deleteGuestData));
    await tester.pumpAndSettle();
  }

  void expectNothingDeleted() {
    verifyNever(
      () => dataDeletion.deleteEverything(
        deleteLocalFiles: any(named: 'deleteLocalFiles'),
        prefs: any(named: 'prefs'),
      ),
    );
    verifyNever(() => auth.deleteAccount());
  }

  testWidgets('a request that could not be filed deletes nothing and says '
      'so', (tester) async {
    when(() => requests.requestDeletion()).thenAnswer((_) async {
      calls.add('request');
      return false;
    });
    when(
      () => requests.requestStatus(),
    ).thenAnswer((_) async => DeletionRequestStatus.none);

    await deleteGuestData(tester);

    expectNothingDeleted();
    expect(calls, ['request']);
    expect(
      find.text(
        "We couldn't file your deletion request, so nothing was deleted. "
        'Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(analytics.loggedEvents, isEmpty);
  });

  testWidgets('a request still waiting on this device deletes nothing, keeps '
      'the guest signed in and says it will be sent when online', (
    tester,
  ) async {
    when(() => requests.requestDeletion()).thenAnswer((_) async {
      calls.add('request');
      return false;
    });
    when(
      () => requests.requestStatus(),
    ).thenAnswer((_) async => DeletionRequestStatus.pending);

    await deleteGuestData(tester);

    expectNothingDeleted();
    verifyNever(() => auth.signOut());
    expect(find.text(en.accountDeletionQueued), findsOneWidget);
    expect(analytics.loggedEvents, isEmpty);
  });

  testWidgets('Firebase refusing to delete the anonymous user after the wipe '
      'keeps the request, says it is scheduled in guest words and signs '
      'out', (tester) async {
    when(() => auth.deleteAccount()).thenAnswer((_) async {
      calls.add('deleteAuth');
      throw FirebaseAuthException(code: 'requires-recent-login');
    });

    await deleteGuestData(tester);

    expect(calls, ['request', 'wipe', 'deleteAuth', 'signOut']);
    verifyNever(() => requests.withdraw());
    verifyNever(() => auth.reauthenticateWithGoogle());
    verify(() => auth.signOut()).called(1);
    expect(
      find.text(
        'Your guest data and anonymous account are scheduled for deletion '
        'and will be fully deleted within 7 days.',
      ),
      findsOneWidget,
    );
    expect(analytics.loggedEvents, isEmpty);
  });

  testWidgets('full success deletes in the safe order, logs the guest event '
      'once and says so', (tester) async {
    await deleteGuestData(tester);

    expect(calls, ['request', 'wipe', 'deleteAuth', 'signOut']);
    verifyNever(() => auth.reauthenticateWithGoogle());
    expect(analytics.loggedEvents, hasLength(1));
    expect(analytics.loggedEvents.single.name, 'guest_mode_data_deleted');
    expect(analytics.loggedEvents.single.parameters, {'method': 'manual'});
    expect(
      find.text('Guest data and anonymous account deleted successfully'),
      findsOneWidget,
    );
  });
}
