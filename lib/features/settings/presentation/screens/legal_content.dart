/// Shared legal document content (Privacy Policy, Terms of Service).
///
/// Kept in one place so every screen that links to these documents (About,
/// Sign In, ...) shows the exact same text via [LegalScreen].
library;

/// Hosted, always-current privacy policy.
const String hostedPrivacyPolicyUrl =
    'https://ravitejakamalapuram.github.io/privacy/invtrack.html';

/// The one support address shown anywhere in the app.
const String supportEmailAddress = 'support@invtracker.app';

const String privacyPolicyContent =
    '''
**Privacy Policy**

Last updated: October 4, 2026

1. **Introduction**
   InvTracker ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how your personal information is collected, used, and disclosed by InvTracker.

2. **Data Collection**
   Your data is stored in InvTrack's Google Firebase (Cloud Firestore) project under your account, so it syncs across your devices and works offline. Google encrypts it in transit and at rest. In the app, only your signed-in account can see your records. The developer can technically access stored data and does so only to answer a support request from you, to process a deletion request, or when the law requires it. We do not sell your data, and we do not use it for advertising. If you choose to sign in with Google, we receive your name, email and a unique user ID to create your account; we do not access your Drive, Gmail or Sheets.

   We also use Google Firebase Analytics, Crashlytics and Performance Monitoring to measure app usage and diagnose crashes and slowness. This diagnostic data is associated with your user ID and device identifiers, and it is always on (there is currently no opt-out). Amounts are reported only in ranges, not exact values. You can delete your account and data in Settings > Data & Account.

3. **Data Usage**
   Your data is used exclusively to provide you with investment tracking features. We do not sell, trade, or rent your personal identification information to others.

4. **Security**
   We use administrative, technical, and physical security measures to help protect your personal information. While we have taken reasonable steps to secure the personal information you provide to us, please be aware that despite our efforts, no security measures are perfect or impenetrable.

5. **Contact Us**
   If you have questions about this Privacy Policy, please contact us at $supportEmailAddress.

   The full, current policy is available at $hostedPrivacyPolicyUrl
''';

const String termsOfServiceContent = '''
**Terms of Service**

Last updated: September 27, 2026

1. **Agreement to Terms**
   By using our mobile application, you agree to be bound by these Terms of Service.

2. **Intellectual Property**
   The Service and its original content, features, and functionality are the exclusive property of InvTracker.

3. **Disclaimer**
   Your use of the Service is at your sole risk. The Service is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind.

4. **Investment Advice**
   InvTracker is a tracking tool only. We do not provide financial, investment, or tax advice. Always consult with qualified professionals.

5. **Governing Law**
   These Terms shall be governed by the laws of India.
''';
