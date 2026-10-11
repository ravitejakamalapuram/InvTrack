// A41 (#784): a guest who links Google keeps their UID and data. That is the
// "guest became an account" step of the activation funnel, logged as
// account_link_success{method: link}, and only when the link really worked.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/handlers/google_sign_in_handler.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../helpers/analytics_privacy.dart';
import '../../../../mocks/fake_auth_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';

class _LinkButton extends ConsumerWidget {
  const _LinkButton({required this.onResult});

  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final handler = GoogleSignInHandler(ref: ref, context: context);
            onResult(await handler.handleSignIn());
          },
          child: const Text('Link'),
        ),
      ),
    );
  }
}

void main() {
  late FakeAuthRepository authRepo;
  late FakeAnalyticsService analytics;
  bool? handlerResult;

  /// The guest, now linked to Google: same UID, no longer anonymous.
  const linked = UserEntity(
    id: 'anon-uid',
    email: 'ravi@example.com',
    displayName: 'Ravi',
  );

  setUp(() {
    authRepo = FakeAuthRepository(guestUser);
    analytics = FakeAnalyticsService();
    handlerResult = null;
  });

  Future<void> tapLink(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          analyticsServiceProvider.overrideWithValue(analytics),
          googleSignInInitializedProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _LinkButton(onResult: (r) => handlerResult = r),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
  }

  Iterable<({String name, Map<String, Object>? parameters})> linkSuccesses() =>
      analytics.loggedEvents.where((e) => e.name == 'account_link_success');

  testWidgets(
    'a successful link logs account_link_success{method: link} once',
    (tester) async {
      authRepo.onLinkAnonymousToGoogle = () async => linked;

      await tapLink(tester);

      expect(handlerResult, isTrue);
      expect(linkSuccesses(), hasLength(1));
      expect(linkSuccesses().single.parameters, {'method': 'link'});
      expectPrivacySafe(
        linkSuccesses().single,
        allowedStrings: {
          'method': {'link'},
        },
      );
    },
  );

  final linksThatDidNotHappen = <String, Future<UserEntity?> Function()>{
    'the user cancelled the Google picker': () async => throw AuthException(
      technicalMessage: 'cancelled',
      shouldReport: false,
      code: AuthExceptionCode.cancelled,
    ),
    'linking failed': () async => throw Exception('network error'),
    'Firebase returned a user that is still a guest': () async => guestUser,
  };
  for (final MapEntry(key: reason, value: link)
      in linksThatDidNotHappen.entries) {
    testWidgets('when $reason, no account_link_success is logged', (
      tester,
    ) async {
      authRepo.onLinkAnonymousToGoogle = link;

      await tapLink(tester);

      expect(handlerResult, isFalse);
      expect(linkSuccesses(), isEmpty);
    });
  }

  testWidgets('someone who is already signed in with Google is not a link', (
    tester,
  ) async {
    authRepo = FakeAuthRepository(googleUser);

    await tapLink(tester);

    expect(handlerResult, isTrue);
    expect(linkSuccesses(), isEmpty);
  });
}
