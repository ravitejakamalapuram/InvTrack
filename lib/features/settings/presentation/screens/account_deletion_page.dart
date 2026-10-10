import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_content.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the web page where anyone, with or without the app, can ask for
/// their account to be deleted. Shared by About and Help & FAQ so the address
/// comes from [hostedAccountDeletionUrl] only. Returns false when no browser
/// opened it. The exception is dropped on purpose: its text is not logged.
Future<bool> openAccountDeletionPage() async {
  try {
    return await launchUrl(
      Uri.parse(hostedAccountDeletionUrl),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// Opens the page, or when no browser can, copies the address to the clipboard
/// and says so, as About does for the support email. Stops without copying or
/// showing anything when the screen was left while the launch was pending.
Future<void> openAccountDeletionPageOrCopyLink(BuildContext context) async {
  if (await openAccountDeletionPage()) return;
  if (!context.mounted) return;
  await Clipboard.setData(const ClipboardData(text: hostedAccountDeletionUrl));
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l10n.accountDeletionLinkCopiedMessage(hostedAccountDeletionUrl),
      ),
      action: SnackBarAction(label: l10n.ok, onPressed: () {}),
    ),
  );
}
