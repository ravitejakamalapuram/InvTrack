import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_import_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_auth_repository.dart';
import '../../../../mocks/fake_guest_merge.dart';
import '../../../../mocks/mock_analytics_service.dart';

const _guest1 = UserEntity(id: 'guest1', email: '', isAnonymous: true);
const _guest2 = UserEntity(id: 'guest2', email: '', isAnonymous: true);
const _google1 = UserEntity(id: 'google1', email: 'existing@example.com');

/// The SharedPreferences key of the pending-merge marker.
const _pendingKey = 'guest_merge_pending';

/// A guest merge interrupted by process death, and the next launch (A79).
void main() {
  late SharedPreferences prefs;
  late GuestBackupStore store;
  late InMemoryGuestBackupStore memoryStore;
  late RecordingGuestImportService importer;
  late FakeGuestExportService exportService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    memoryStore = InMemoryGuestBackupStore();
    store = memoryStore;
    importer = RecordingGuestImportService();
    exportService = FakeGuestExportService();
  });

  /// Starts the app (a new process) signed in as [user]. Preferences and
  /// backups on disk survive from one launch to the next.
  Future<(ProviderContainer, FakeAuthRepository)> launch(
    UserEntity? user,
  ) async {
    final auth = FakeAuthRepository(user);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(auth),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        // The guest and the Google account use different base currencies.
        currencyCodeProvider.overrideWith((ref) {
          final id = ref.watch(authStateProvider).value?.id;
          return id == _google1.id ? 'INR' : 'EUR';
        }),
        dataExportServiceProvider.overrideWith((ref) => exportService),
        guestBackupStoreProvider.overrideWithValue(store),
        guestBackupReaderProvider.overrideWithValue(
          (path) async => memoryStore.files[path]!,
        ),
        dataImportServiceProvider.overrideWith((ref) {
          final id = ref.watch(authStateProvider).value?.id;
          return id == _google1.id ? importer : null;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(authStateProvider, (_, _) {});
    await container.read(authStateProvider.future);
    return (container, auth);
  }

  GuestBackupMergeService service(ProviderContainer container) =>
      container.read(guestBackupMergeServiceProvider);

  Future<void> writeMarker(String guestId, String backupPath) =>
      prefs.setString(
        _pendingKey,
        jsonEncode({'guestId': guestId, 'path': backupPath}),
      );

  group('pending-merge marker', () {
    test('is written before the sign-in and holds only the guest id and the '
        'backup path', () async {
      final (container, auth) = await launch(_guest1);
      String? markerAtSignIn;
      auth.onSignInWithGoogle = () async {
        markerAtSignIn = prefs.getString(_pendingKey);
        auth.emit(_google1);
        return _google1;
      };

      await service(
        container,
      ).backupAndSignIn(confirmDetailsNotMoved: (_) async => true);

      expect(markerAtSignIn, isNotNull);
      expect(jsonDecode(markerAtSignIn!), {
        'guestId': 'guest1',
        'path': '/data/app/files/guest_backups/guest1/backup_0.zip',
      });
      // The backup reached the Google account, so the marker is cleared.
      expect(prefs.containsKey(_pendingKey), isFalse);
    });

    test('is cleared when the sign-in is cancelled', () async {
      final (container, _) = await launch(_guest1);

      final outcome = await service(
        container,
      ).backupAndSignIn(confirmDetailsNotMoved: (_) async => true);

      expect(outcome, isA<GuestMergeCancelled>());
      expect(prefs.containsKey(_pendingKey), isFalse);
      expect(memoryStore.files, isEmpty);
    });
  });

  group('next launch', () {
    test('signed in to the Google account: a backup still owned by the guest '
        'is handed to it and offered, and the marker is cleared', () async {
      final path = await store.save(guestBackupBytes, ownerId: 'guest1');
      await writeMarker('guest1', path);

      final (container, _) = await launch(_google1);
      final offered = await service(
        container,
      ).recoverInterruptedMerge(_google1);

      expect(await store.list(ownerId: 'guest1'), isEmpty);
      final owned = await store.list(ownerId: 'google1');
      expect(owned, hasLength(1));
      expect(offered, owned);
      expect(prefs.containsKey(_pendingKey), isFalse);
    });

    test('still the same guest: the sign-in never happened, so the redundant '
        'backup is deleted and the marker cleared', () async {
      final path = await store.save(guestBackupBytes, ownerId: 'guest1');
      await writeMarker('guest1', path);

      final (container, _) = await launch(_guest1);
      final offered = await service(container).recoverInterruptedMerge(_guest1);

      expect(offered, isEmpty);
      expect(memoryStore.files, isEmpty);
      expect(prefs.containsKey(_pendingKey), isFalse);
    });

    test('another guest: the backup is not handed over', () async {
      final path = await store.save(guestBackupBytes, ownerId: 'guest1');
      await writeMarker('guest1', path);

      final (container, _) = await launch(_guest2);
      final offered = await service(container).recoverInterruptedMerge(_guest2);

      expect(offered, isEmpty);
      expect(await store.list(ownerId: 'guest1'), [path]);
      expect(prefs.containsKey(_pendingKey), isTrue);
    });

    test('no backups: nothing is offered', () async {
      final (container, _) = await launch(_google1);

      expect(await service(container).recoverInterruptedMerge(_google1), []);
    });

    test(
      'a backup the account owns is offered until the user answers once',
      () async {
        final path = await store.save(guestBackupBytes, ownerId: 'google1');

        var (container, _) = await launch(_google1);
        expect(await service(container).recoverInterruptedMerge(_google1), [
          path,
        ]);
        await service(container).markOffered(path);

        (container, _) = await launch(_google1);
        expect(await service(container).recoverInterruptedMerge(_google1), []);
        expect(await store.list(ownerId: 'google1'), [path]);
      },
    );
  });

  group('Import now', () {
    /// A merge whose import did not finish. Returns the backup's path, now
    /// owned by the Google account.
    Future<String> interruptedMerge() async {
      final (container, auth) = await launch(_guest1);
      auth.onSignInWithGoogle = () async {
        auth.emit(_google1);
        return _google1;
      };
      importer.error = StateError('import stopped');
      final outcome = await service(
        container,
      ).backupAndSignIn(confirmDetailsNotMoved: (_) async => true);
      expect(outcome, isA<GuestMergeImportFailed>());
      importer
        ..error = null
        ..calls.clear();
      return (outcome as GuestMergeImportFailed).backupPath;
    }

    test('a complete import deletes the backup', () async {
      final path = await interruptedMerge();

      final (container, _) = await launch(_google1);
      expect(await service(container).recoverInterruptedMerge(_google1), [
        path,
      ]);
      final result = await service(container).importSavedBackup(path);

      expect(result, GuestBackupImport.complete);
      expect(importer.calls, hasLength(1));
      final (bytes, strategy, currency) = importer.calls.single;
      expect(bytes, guestBackupBytes);
      expect(strategy, ImportStrategy.merge);
      // The guest's base currency, for rows that carry none.
      expect(currency, 'EUR');
      expect(await store.list(ownerId: 'google1'), isEmpty);
    });

    test('an incomplete import keeps the backup', () async {
      final path = await interruptedMerge();
      importer.result = incompleteGuestImport;

      final (container, _) = await launch(_google1);
      final result = await service(container).importSavedBackup(path);

      expect(result, GuestBackupImport.incomplete);
      expect(await store.list(ownerId: 'google1'), [path]);
    });

    test('a backup saved before its contents were counted is imported but '
        'kept', () async {
      final path = await store.save(guestBackupBytes, ownerId: 'google1');

      final (container, _) = await launch(_google1);
      final result = await service(container).importSavedBackup(path);

      expect(result, GuestBackupImport.unchecked);
      expect(importer.calls.single.$3, 'INR');
      expect(await store.list(ownerId: 'google1'), [path]);
    });
  });

  test(
    'Delete Account after the hand-over leaves no guest backup file',
    () async {
      final temp = await Directory.systemTemp.createTemp('guest_backups_test');
      addTearDown(() => temp.delete(recursive: true));
      store = FileGuestBackupStore(() async => temp);
      final path = await store.save(guestBackupBytes, ownerId: 'guest1');
      await writeMarker('guest1', path);

      final (container, _) = await launch(_google1);
      await service(container).recoverInterruptedMerge(_google1);
      // What Delete Account runs for the signed-in user.
      await store.deleteAll(ownerId: 'google1');

      final left = await Directory(
        '${temp.path}/guest_backups',
      ).list(recursive: true).where((e) => e is File).toList();
      expect(left, isEmpty);
    },
  );
}
