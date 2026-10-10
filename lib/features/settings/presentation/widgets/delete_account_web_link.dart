import 'package:flutter/material.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// "Delete your account on the web" link for Help & FAQ. Pure UI: the screen
/// passes what a tap does (see openAccountDeletionPageOrCopyLink).
class DeleteAccountWebLink extends StatelessWidget {
  const DeleteAccountWebLink({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      // One node for a screen reader: the button, its name and the hint.
      child: MergeSemantics(
        child: Semantics(
          hint: l10n.opensInBrowser,
          child: TextButton.icon(
            key: const Key('delete_account_web_link'),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.deleteAccountOnTheWeb),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
