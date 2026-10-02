import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_import_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';

/// Result of [GuestBackupMergeService.backupAndSignIn].
sealed class GuestMergeOutcome {
  const GuestMergeOutcome();
}

/// The user closed the Google account picker. Nothing changed: the guest is
/// still signed in with all of their data.
class GuestMergeCancelled extends GuestMergeOutcome {
  const GuestMergeCancelled();
}

/// Signed in to Google and every guest record was imported into it.
class GuestMergeSucceeded extends GuestMergeOutcome {
  const GuestMergeSucceeded(this.result);

  final ZipImportResult result;
}

/// Signed in to Google, but the guest data was not fully imported: the
/// import failed, or it skipped or could not add some records (for example
/// an investment or goal whose name the Google account already uses).
///
/// The guest account can no longer be reached, so [backup] is the only full
/// copy of the guest data and the user must be offered it
/// ([GuestBackupMergeService.shareBackup]).
class GuestMergeImportFailed extends GuestMergeOutcome {
  const GuestMergeImportFailed(this.backup);

  final Uint8List backup;
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

  /// Backs up the guest's data in memory, signs in with Google and imports
  /// the backup into that account with [ImportStrategy.merge].
  ///
  /// Throws if the backup cannot be created; the guest is then still signed
  /// in and nothing has changed.
  Future<GuestMergeOutcome> backupAndSignIn() async {
    final exportService = _ref.read(dataExportServiceProvider);
    if (exportService == null) {
      throw StateError('No signed-in guest to back up');
    }
    final export = await exportService.exportAsZipBytes();
    final backup = export.bytes;
    // The guest's base currency, read before the session switch, applies to
    // backup rows that carry no currency of their own.
    final baseCurrency = _ref.read(currencyCodeProvider);

    final analytics = _ref.read(analyticsServiceProvider);
    await analytics.logEvent(
      name: 'backup_created',
      parameters: {'trigger': 'account_linking_failure'},
    );

    final googleUser = await _ref
        .read(authRepositoryProvider)
        .signInWithGoogle();
    if (googleUser == null) {
      LoggerService.info('Guest backup merge cancelled at Google sign-in');
      return const GuestMergeCancelled();
    }

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
                export.investments - result.investmentsImported,
            'cashFlowsMissing': export.cashFlows - result.cashflowsImported,
            'goalsMissing': export.goals - result.goalsImported,
            'documentsMissing': export.documents - result.documentsImported,
          },
        );
        return GuestMergeImportFailed(backup);
      }
      LoggerService.info('Guest backup merged into Google account');
      return GuestMergeSucceeded(result);
    } catch (e, st) {
      LoggerService.error(
        'Guest backup import after Google sign-in failed',
        error: e,
        stackTrace: st,
      );
      return GuestMergeImportFailed(backup);
    }
  }

  /// Whether [result] added every record of [export]. Merge reports skipped
  /// duplicates and failed documents or FIRE settings only as warnings, and
  /// the export can hold investments the import does not recreate, so the
  /// counts are compared as well.
  static bool _isComplete(ZipImportResult result, ZipExport export) =>
      !result.hasErrors &&
      result.warnings.isEmpty &&
      result.investmentsImported == export.investments &&
      result.cashflowsImported == export.cashFlows &&
      result.goalsImported == export.goals &&
      result.documentsImported == export.documents &&
      (!export.hasFireSettings || result.fireSettingsImported);

  /// Opens the share sheet for a backup returned in [GuestMergeImportFailed].
  Future<void> shareBackup(Uint8List backup) async {
    final exportService = _ref.read(dataExportServiceProvider);
    if (exportService == null) {
      throw StateError('No signed-in user to share the backup');
    }
    await exportService.shareZipBytes(backup);
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
