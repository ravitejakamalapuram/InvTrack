import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_content.dart';
import 'package:inv_tracker/features/settings/presentation/screens/legal_screen.dart';

void main() {
  test('privacy policy text matches real Firebase behaviour', () {
    final text = privacyPolicyContent.toLowerCase();
    expect(privacyPolicyContent, contains('Google Firebase'));
    expect(privacyPolicyContent, contains('Crashlytics'));
    expect(privacyPolicyContent, contains(hostedPrivacyPolicyUrl));
    expect(text, isNot(contains('stored locally')));
    expect(text, isNot(contains('never uploaded')));
  });

  // A69 (C074, SEC-05): the data sits in the developer's Firebase project
  // without client-side encryption, so the operator can read it. The policy
  // must not say that only the user can read it or call it a private cloud.
  test('privacy policy does not claim only the user can read the data', () {
    final text = privacyPolicyContent.toLowerCase();
    expect(text, isNot(contains('only you can read')));
    expect(text, isNot(contains('private cloud')));
    expect(
      privacyPolicyContent,
      isNot(
        contains(
          RegExp(r'only\s+you\s+can\s+(read|see|access)', caseSensitive: false),
        ),
      ),
    );
    expect(
      privacyPolicyContent,
      isNot(contains(RegExp(r'private\s+cloud', caseSensitive: false))),
    );
  });

  test('privacy policy says plainly who can read stored data', () {
    expect(privacyPolicyContent, contains('Last updated: October 4, 2026'));
    expect(
      privacyPolicyContent,
      contains(
        "Your data is stored in InvTrack's Google Firebase (Cloud Firestore) "
        'project under your account, so it syncs across your devices and '
        'works offline. Google encrypts it in transit and at rest. In the '
        'app, only your signed-in account can see your records. The '
        'developer can technically access stored data and does so only to '
        'answer a support request from you, to process a deletion request, '
        'or when the law requires it. We do not sell your data, and we do '
        'not use it for advertising.',
      ),
    );
  });

  testWidgets('LegalScreen shows hosted-policy link when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LegalScreen(
          title: 'Privacy',
          content: 'x',
          linkUri: Uri.parse(hostedPrivacyPolicyUrl),
          linkLabel: 'View online',
        ),
      ),
    );
    expect(find.byKey(const Key('legal_screen_link')), findsOneWidget);
    expect(find.text('View online'), findsOneWidget);
  });

  testWidgets('LegalScreen has no link by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalScreen(title: 'T', content: 'x')),
    );
    expect(find.byKey(const Key('legal_screen_link')), findsNothing);
  });
}
