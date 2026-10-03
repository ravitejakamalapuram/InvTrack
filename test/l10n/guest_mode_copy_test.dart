import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

/// A05 / ADOPT-06, SEC-03: guest (anonymous) accounts cannot be opened on
/// another device or after signing out, so the copy must not promise it.
void main() {
  final l10n = AppLocalizationsEn();

  test('FAQ answer about guest mode does not promise cross-device access', () {
    expect(l10n.whatIsGuestModeAnswer, isNot(contains('across devices')));
    expect(
      l10n.whatIsGuestModeAnswer,
      'Guest Mode lets you use InvTrack without signing in. Your data is '
      'stored under an anonymous guest account that only this device can '
      'reach. You cannot open it on another device, and signing out or '
      'uninstalling the app loses it permanently. To keep your data, tap '
      '"Sign In to Link Account" in Settings to link a Google account.',
    );
  });

  test('FAQ answer about linking describes the automatic merge', () {
    expect(
      l10n.howToLinkGuestAccountAnswer,
      "Tap the 'Sign In to Link Account' button in Settings. If that Google "
      'account already exists, InvTrack backs up your guest data, signs you '
      'in to the Google account and adds your guest data to it. If some of '
      'it cannot be added, a backup is kept on this device and you can '
      'share it from Settings > Data & Account.',
    );
  });

  // A05-F1 / integration-11: the merge is automatic, so the FAQ must not
  // tell guests to import a ZIP by hand, and must be honest about what the
  // merge cannot move yet.
  test('FAQ answer about guest data describes the automatic merge', () {
    expect(
      l10n.whatHappensToGuestDataAnswer,
      isNot(contains('which you can import to merge')),
    );
    expect(
      l10n.whatHappensToGuestDataAnswer,
      'If your Google account is new, your guest data is linked to it '
      'automatically. If your Google account already exists, InvTrack backs '
      'up your guest data and adds it to that account for you, so there is '
      'nothing to import by hand. Some investment details, such as maturity '
      'dates, interest rates, payout frequency and notes, cannot be moved '
      'yet and are not in the backup, so InvTrack tells you before you sign '
      'in if any would be lost. If some investments, cash flows or goals '
      'cannot be added, a backup of them is kept on this device until you '
      'delete it in Settings > Data & Account.',
    );
  });

  test('guest mode notice warns about sign-out and uninstall', () {
    expect(l10n.guestModeNotice, isNot(contains('across devices')));
    expect(
      l10n.guestModeNotice,
      'As a guest, your data can only be reached from this device. If you '
      'sign out or uninstall the app, it is lost for good. Link a Google '
      'account in Settings to keep it.',
    );
  });
}
