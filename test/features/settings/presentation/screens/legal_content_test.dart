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
