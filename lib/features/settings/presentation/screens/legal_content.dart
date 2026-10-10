/// Shared legal document content (Privacy Policy, Terms of Service).
///
/// Kept in one place so every screen that links to these documents (About,
/// Sign In, ...) shows the exact same text via [LegalScreen].
library;

import 'package:intl/intl.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Hosted, always-current privacy policy.
const String hostedPrivacyPolicyUrl =
    'https://ravitejakamalapuram.github.io/privacy/invtrack.html';

/// The one support address shown anywhere in the app.
const String supportEmailAddress = 'support@invtracker.app';

/// Date the privacy policy last changed.
final DateTime privacyPolicyLastUpdated = DateTime(2026, 10, 4);

/// The in-app privacy policy, from the ARB file, with the support address,
/// hosted URL and date (formatted for [l10n]'s locale) filled in.
String privacyPolicyText(AppLocalizations l10n) => l10n.privacyPolicyBody(
  DateFormat.yMMMMd(l10n.localeName).format(privacyPolicyLastUpdated),
  supportEmailAddress,
  hostedPrivacyPolicyUrl,
);

const String termsOfServiceContent = '''
**Terms of Service**

Last updated: September 27, 2026

1. **Agreement to Terms**
   By using our mobile application, you agree to be bound by these Terms of Service.

2. **Intellectual Property**
   The Service and its original content, features, and functionality are the exclusive property of InvTrack.

3. **Disclaimer**
   Your use of the Service is at your sole risk. The Service is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind.

4. **Investment Advice**
   InvTrack is a tracking tool only. We do not provide financial, investment, or tax advice. Always consult with qualified professionals.

5. **Governing Law**
   These Terms shall be governed by the laws of India.
''';
