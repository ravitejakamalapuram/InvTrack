import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// The text of an import error, the one place the data layer's [ImportError]
/// values become words (#1103).
String importErrorText(
  AppLocalizations l10n,
  ImportError error,
) => switch (error.kind) {
  ImportErrorKind.invalidZip => l10n.importErrorInvalidZip,
  ImportErrorKind.metadataMissing => l10n.importErrorMetadataMissing,
  ImportErrorKind.metadataUnparseable => l10n.importErrorMetadataUnparseable,
  ImportErrorKind.cashflowsUnreadable => l10n.importErrorCashflowsUnreadable,
  ImportErrorKind.cashflowsMissing => l10n.importErrorCashflowsMissing,
  ImportErrorKind.cashflowsNoRows => l10n.importErrorCashflowsNoRows,
  ImportErrorKind.fileDamaged => l10n.importErrorFileDamaged(error.detail),
  ImportErrorKind.archiveFailures => l10n.importErrorArchiveFailures(
    error.count,
  ),
  ImportErrorKind.rowDetail => error.detail,
};
