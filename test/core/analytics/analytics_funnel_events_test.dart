// A41 (#784): the activation funnel events, checked on the real service
// against a mocked Firebase, so the parameter shaping is what Firebase gets.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/analytics_privacy.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  late _MockFirebaseAnalytics firebase;
  late AnalyticsService service;
  final sent = <({String name, Map<String, Object>? parameters})>[];

  setUp(() {
    sent.clear();
    firebase = _MockFirebaseAnalytics();
    when(
      () => firebase.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((call) async {
      sent.add((
        name: call.namedArguments[#name] as String,
        parameters: call.namedArguments[#parameters] as Map<String, Object>?,
      ));
    });
    service = AnalyticsService(analytics: firebase);
  });

  test(
    'investment_created says whether an amount was entered, as 1/0',
    () async {
      await service.logInvestmentCreated(
        investmentType: 'fd',
        hasNotes: false,
        hasAmount: true,
      );

      expect(sent.single.name, 'investment_created');
      expect(sent.single.parameters, {
        'investment_type': 'fd',
        'has_notes': 0,
        'has_amount': 1,
      });
      expectPrivacySafe(
        sent.single,
        allowedStrings: {
          'investment_type': {'fd'},
        },
      );
    },
  );

  test('xirr_viewed carries the surface and whether the figure is an '
      'estimate', () async {
    await service.logXirrViewed(surface: 'overview', isEstimate: false);
    await service.logXirrViewed(surface: 'investment_detail', isEstimate: true);

    expect(sent.map((e) => e.name), ['xirr_viewed', 'xirr_viewed']);
    expect(sent[0].parameters, {'surface': 'overview', 'is_estimate': 0});
    expect(sent[1].parameters, {
      'surface': 'investment_detail',
      'is_estimate': 1,
    });
    for (final event in sent) {
      expectPrivacySafe(
        event,
        allowedStrings: {
          'surface': {'overview', 'investment_detail'},
        },
      );
    }
  });

  test('account_link_success carries only the method', () async {
    await service.logAccountLinkSuccess(method: 'link');
    await service.logAccountLinkSuccess(method: 'merge');

    expect(sent.map((e) => e.name), [
      'account_link_success',
      'account_link_success',
    ]);
    expect(sent[0].parameters, {'method': 'link'});
    expect(sent[1].parameters, {'method': 'merge'});
    for (final event in sent) {
      expectPrivacySafe(
        event,
        allowedStrings: {
          'method': {'link', 'merge'},
        },
      );
    }
  });

  test('account_link_failure carries only the reason', () async {
    await service.logAccountLinkFailure(reason: 'google_account_exists');

    expect(sent.single.name, 'account_link_failure');
    expect(sent.single.parameters, {'reason': 'google_account_exists'});
    expectPrivacySafe(
      sent.single,
      allowedStrings: {
        'reason': {'google_account_exists'},
      },
    );
  });
}
