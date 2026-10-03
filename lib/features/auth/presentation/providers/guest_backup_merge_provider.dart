import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_import_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:path_provider/path_provider.dart';

/// Result of [GuestBackupMergeService.backupAndSignIn].
sealed class GuestMergeOutcome {
  const GuestMergeOutcome();
}

/// The user closed the Google account picker. Nothing changed: the guest is
/// still signed in with all of their data.
class GuestMergeCancelled extends GuestMergeOutcome {
  const GuestMergeCancelled();
}

/// Signed in to Google and every guest record, with every detail, was
/// imported into it.
class GuestMergeSucceeded extends GuestMergeOutcome {
  const GuestMergeSucceeded(this.result);

  final ZipImportResult result;
}

/// Signed in to Google, but the guest data was not fully imported: the
/// import failed, or it skipped or could not add some records (for example
/// an investment or goal whose name the Google account already uses).
///
/// The guest account can no longer be reached, so the backup at
/// [backupPath] is the only copy of the missing records. It stays in
/// [GuestBackupStore] until the user deletes it, and the user must be
/// offered it ([GuestBackupMergeService.shareBackup]).
class GuestMergeImportFailed extends GuestMergeOutcome {
  const GuestMergeImportFailed(this.backupPath);

  final String backupPath;
}

/// Signed in to Google and every guest record was imported, but some guest
/// data was left behind because the backup cannot carry it: investment
/// details such as maturity date, rate, payout frequency and notes (and the
/// reminders that depend on them), or expected cash flows. The guest agreed
/// to this before the sign-in.
///
/// This is not a full move and must not be reported as one. The backup holds
/// nothing the Google account lacks, so it is not kept.
class GuestMergeDetailsNotMoved extends GuestMergeOutcome {
  const GuestMergeDetailsNotMoved(this.result);

  final ZipImportResult result;
}

/// Moves a guest's data into a Google account that already exists, used when
/// linking fails with credential-already-in-use.
///
/// This runs in a provider, not in a widget, because signing in to another
/// account rebuilds the router and disposes the screen that started it.
///
/// The guest's own Firestore data is not deleted here. The backup does not
/// yet carry every investment field (maturity date, rate, notes and others),
/// so deleting the guest copy after a merge would destroy them for good.
/// Once the Google session starts, the client also can no longer act as the
/// anonymous user.
class GuestBackupMergeService {
  GuestBackupMergeService(this._ref);

  final Ref _ref;

  /// How long to wait for the new Google session to reach the app's
  /// providers before giving up on the automatic import.
  static const sessionSwitchTimeout = Duration(seconds: 15);

  /// Backs up the guest's data to app-private storage, signs in with Google
  /// and imports the backup into that account with [ImportStrategy.merge].
  ///
  /// The backup cannot carry investments without cash flows, some investment
  /// details and expected cash flows (see [ZipExport.carriesEverything]),
  /// and they cannot be reached once
  /// the guest session ends. If the guest has any, [confirmDetailsNotMoved]
  /// is asked first, before anything is saved or signed in; if it returns
  /// false the merge stops with [GuestMergeCancelled].
  ///
  /// The backup belongs to the guest until the sign-in and to the Google
  /// account after it, so no other account on the device can see it. It is
  /// deleted after a merge that added every record, or when the sign-in did
  /// not happen. Otherwise it stays on the device, because the guest account
  /// cannot be reached after the sign-in.
  ///
  /// Throws if the backup cannot be created or saved, or the sign-in fails;
  /// the guest is then still signed in and nothing has changed.
  Future<GuestMergeOutcome> backupAndSignIn({
    required Future<bool> Function(ZipExport export) confirmDetailsNotMoved,
  }) async {
    final exportService = _ref.read(dataExportServiceProvider);
    final authRepository = _ref.read(authRepositoryProvider);
    final guestId = authRepository.currentUser?.id;
    if (exportService == null || guestId == null) {
      throw StateError('No signed-in guest to back up');
    }
    final export = await exportService.exportAsZipBytes();
    if (!export.carriesEverything && !await confirmDetailsNotMoved(export)) {
      LoggerService.info('Guest backup merge cancelled: details not movable');
      return const GuestMergeCancelled();
    }
    final backup = export.bytes;
    // The guest's base currency, read before the session switch, applies to
    // backup rows that carry no currency of their own.
    final baseCurrency = _ref.read(currencyCodeProvider);

    // On disk before the guest session ends, so the only copy of the guest
    // data survives a closed prompt, a timed-out snackbar and process death.
    final store = _ref.read(guestBackupStoreProvider);
    var backupPath = await store.save(backup, ownerId: guestId);
    _ref.invalidate(savedGuestBackupsProvider);

    final analytics = _ref.read(analyticsServiceProvider);
    await analytics.logEvent(
      name: 'backup_created',
      parameters: {'trigger': 'account_linking_failure'},
    );

    final UserEntity? googleUser;
    try {
      googleUser = await authRepository.signInWithGoogle();
    } catch (_) {
      final signedIn = authRepository.currentUser?.id;
      if (signedIn == guestId) {
        // Nothing changed, so the backup is redundant; a retry makes a new one.
        await _deleteBackup(backupPath);
      } else if (signedIn != null) {
        await _transferBackup(backupPath, signedIn);
      }
      rethrow;
    }
    if (googleUser == null) {
      LoggerService.info('Guest backup merge cancelled at Google sign-in');
      // The guest is still signed in with all of their data.
      await _deleteBackup(backupPath);
      return const GuestMergeCancelled();
    }
    // From here only the Google account may see the backup.
    backupPath = await _transferBackup(backupPath, googleUser.id);

    await analytics.logEvent(
      name: 'account_link_failure',
      parameters: {'reason': 'google_account_exists'},
    );

    try {
      await _waitForSession(googleUser.id);
      final importService = _ref.read(dataImportServiceProvider);
      if (importService == null) {
        throw StateError('Google session not available for import');
      }
      final result = await importService.importFromZip(
        backup,
        ImportStrategy.merge,
        baseCurrency: baseCurrency,
      );
      if (!_isComplete(result, export)) {
        // Counts only: warnings and errors contain investment and goal names.
        LoggerService.warn(
          'Guest backup merge did not import every record',
          metadata: {
            'errorCount': result.errors.length,
            'warningCount': result.warnings.length,
            'investmentsMissing':
                export.investmentsInExport - result.investmentsImported,
            'cashFlowsMissing': export.cashFlows - result.cashflowsImported,
            'goalsMissing': export.goals - result.goalsImported,
            'documentsMissing': export.documents - result.documentsImported,
          },
        );
        return GuestMergeImportFailed(backupPath);
      }
      if (!export.carriesEverything) {
        LoggerService.warn(
          'Guest backup merge left details behind',
          metadata: {
            'investmentsWithDetailsNotInExport':
                export.investmentsWithDetailsNotInExport,
            'investmentsNotInExport': export.investmentsNotInExport,
            'expectedCashFlows': export.expectedCashFlows,
          },
        );
        // Every record the backup holds is now in the Google account.
        await _deleteBackup(backupPath);
        return GuestMergeDetailsNotMoved(result);
      }
      LoggerService.info('Guest backup merged into Google account');
      await _deleteBackup(backupPath);
      return GuestMergeSucceeded(result);
    } catch (e, st) {
      LoggerService.error(
        'Guest backup import after Google sign-in failed',
        error: e,
        stackTrace: st,
      );
      return GuestMergeImportFailed(backupPath);
    }
  }

  /// Deletes a backup that is no longer the only copy of anything. A failure
  /// only leaves a redundant file, which the user can delete in Settings.
  Future<void> _deleteBackup(String backupPath) async {
    try {
      await _ref.read(guestBackupStoreProvider).delete(backupPath);
    } catch (e, st) {
      LoggerService.error(
        'Could not delete redundant guest backup',
        // The type only: file errors carry the backup's path.
        metadata: {'errorType': e.runtimeType.toString()},
        stackTrace: st,
      );
    }
    _ref.invalidate(savedGuestBackupsProvider);
  }

  /// Hands the backup to [ownerId] and returns its new path. If that fails
  /// the backup stays where it is and can still be shared from the prompt.
  Future<String> _transferBackup(String backupPath, String ownerId) async {
    try {
      return await _ref
          .read(guestBackupStoreProvider)
          .transfer(backupPath, toOwnerId: ownerId);
    } catch (e, st) {
      LoggerService.error(
        'Could not hand the guest backup to the signed-in account',
        // The type only: file errors carry the backup's path.
        metadata: {'errorType': e.runtimeType.toString()},
        stackTrace: st,
      );
      return backupPath;
    } finally {
      _ref.invalidate(savedGuestBackupsProvider);
    }
  }

  /// Whether [result] added every record of [export]. Merge reports skipped
  /// duplicates and failed documents or FIRE settings only as warnings, so
  /// the counts are compared as well. Investments without cash flows are not
  /// in the backup (the guest was warned about them), so they are not
  /// expected.
  static bool _isComplete(ZipImportResult result, ZipExport export) =>
      !result.hasErrors &&
      result.warnings.isEmpty &&
      result.investmentsImported == export.investmentsInExport &&
      result.cashflowsImported == export.cashFlows &&
      result.goalsImported == export.goals &&
      result.documentsImported == export.documents &&
      (!export.hasFireSettings || result.fireSettingsImported);

  /// Opens the share sheet for the backup of a [GuestMergeImportFailed].
  /// Sharing does not delete it: only the user can say they have saved it
  /// ([deleteSavedBackups]).
  Future<void> shareBackup(String backupPath) => _share([backupPath]);

  /// Opens the share sheet for every guest backup the signed-in account owns.
  Future<void> shareSavedBackups() async {
    final paths = await _ref
        .read(guestBackupStoreProvider)
        .list(ownerId: _signedInUserId());
    if (paths.isNotEmpty) await _share(paths);
  }

  /// Deletes every guest backup the signed-in account owns, after the user
  /// confirmed it.
  Future<void> deleteSavedBackups() async {
    await _ref
        .read(guestBackupStoreProvider)
        .deleteAll(ownerId: _signedInUserId());
    _ref.invalidate(savedGuestBackupsProvider);
  }

  String _signedInUserId() {
    final userId = _ref.read(authStateProvider).value?.id;
    if (userId == null) throw StateError('No signed-in user');
    return userId;
  }

  Future<void> _share(List<String> paths) async {
    final exportService = _ref.read(dataExportServiceProvider);
    if (exportService == null) {
      throw StateError('No signed-in user to share the backup');
    }
    await exportService.shareZipFiles(paths);
  }

  /// Completes once [authStateProvider] reports the user [userId], so that
  /// the import goes to that user's repositories and not the guest's.
  Future<void> _waitForSession(String userId) async {
    bool isTarget(AsyncValue<UserEntity?> state) => state.value?.id == userId;

    if (isTarget(_ref.read(authStateProvider))) return;

    final switched = Completer<void>();
    final subscription = _ref.listen<AsyncValue<UserEntity?>>(
      authStateProvider,
      (_, next) {
        if (isTarget(next) && !switched.isCompleted) switched.complete();
      },
    );
    try {
      await switched.future.timeout(sessionSwitchTimeout);
    } finally {
      subscription.close();
    }
  }
}

/// Kept alive and independent of any screen so the merge can finish after
/// the sign-in rebuilds the router.
final guestBackupMergeServiceProvider = Provider<GuestBackupMergeService>(
  GuestBackupMergeService.new,
);

/// Guest backups kept in app-private storage (not in Android Auto Backup).
final guestBackupStoreProvider = Provider<GuestBackupStore>(
  (ref) => FileGuestBackupStore(getApplicationSupportDirectory),
);

/// Paths of the guest backups the signed-in account owns on this device, for
/// Settings. Empty when no one is signed in; another account's backups are
/// never listed.
final savedGuestBackupsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final userId = ref.watch(authStateProvider.select((s) => s.value?.id));
  if (userId == null) return const [];
  return ref.watch(guestBackupStoreProvider).list(ownerId: userId);
});
