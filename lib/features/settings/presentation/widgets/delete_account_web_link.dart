import 'package:flutter/material.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_content.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the web page where anyone, with or without the app, can ask for
/// their account to be deleted. Shared by About and Help & FAQ so the address
/// comes from [hostedAccountDeletionUrl] only.
Future<void> openAccountDeletionPage() async {
  try {
    await launchUrl(
      Uri.parse(hostedAccountDeletionUrl),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // No browser to open it with. The address is also in the privacy policy.
  }
}

/// "Delete your account on the web" link for Help & FAQ.
class DeleteAccountWebLink extends StatelessWidget {
  const DeleteAccountWebLink({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: TextButton.icon(
        key: const Key('delete_account_web_link'),
        icon: const Icon(Icons.open_in_new),
        label: Text(l10n.deleteAccountOnTheWeb),
        onPressed: openAccountDeletionPage,
      ),
    );
  }
}
