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
