import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// "Export failed: <reason>" where the reason names the kind of failure and
/// never the exception text, which can carry paths and type names.
String exportFailureMessage(AppLocalizations l10n, Object error) {
  final reason = switch (ErrorHandler.kindOf(error)) {
    ErrorKind.network => l10n.errorReasonNetwork,
    ErrorKind.permission => l10n.errorReasonPermission,
    ErrorKind.unknown => l10n.errorReasonUnknown,
  };
  return l10n.exportFailed(reason);
}
