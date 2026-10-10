import 'package:inv_tracker/core/utils/custom_type_label.dart';
import 'package:inv_tracker/features/investment/domain/models/custom_type_catalog.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// The text that tells the user why a change to the custom types was refused
/// (#936).
String customTypeIssueMessage(AppLocalizations l10n, CustomTypeIssue issue) {
  switch (issue) {
    case CustomTypeIssue.blank:
      return l10n.customTypeErrorBlank;
    case CustomTypeIssue.tooLong:
      return l10n.customTypeErrorTooLong(CustomTypeLabel.maxLength);
    case CustomTypeIssue.duplicate:
      return l10n.customTypeErrorDuplicate;
    case CustomTypeIssue.atCapacity:
      return l10n.customTypeLimitReached(CustomTypeLabel.maxActiveDefinitions);
    case CustomTypeIssue.notFound:
      return l10n.customTypeErrorGeneric;
  }
}
