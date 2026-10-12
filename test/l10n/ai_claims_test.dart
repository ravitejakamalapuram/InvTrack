@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

/// A105: InvTrack has no AI or machine learning. Income Guardian projects
/// expected payouts from the schedule the user enters and a plain weighted
/// average, so no in-app text may call any feature AI-powered or say it uses
/// machine learning.
final _bannedClaims = <String, RegExp>{
  'AI-powered': RegExp(r'\bAI[\s-]*powered\b', caseSensitive: false),
  'machine learning': RegExp(r'machine[\s-]+learning', caseSensitive: false),
};

void main() {
  test('no string in app_en.arb makes an AI or machine learning claim', () {
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final values = arb.entries.where((e) => !e.key.startsWith('@')).toList();
    // The scan must not pass just because it read nothing.
    expect(values.length, greaterThan(100));
    final offending = <String>[];
    for (final e in values) {
      _bannedClaims.forEach((name, pattern) {
        if (pattern.hasMatch(e.value.toString())) {
          offending.add('${e.key}: "$name"');
        }
      });
    }
    expect(offending, isEmpty);
  });

  test('no hard-coded string in lib/ makes an AI or machine learning claim', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.path.replaceAll(r'\', '/').contains('/l10n/generated/'),
        )
        .toList();
    expect(
      files.map((f) => f.path.replaceAll(r'\', '/')),
      contains(
        'lib/features/settings/presentation/screens/debug_settings_screen.dart',
      ),
    );
    final offending = <String>[];
    for (final file in files) {
      final text = file.readAsStringSync();
      _bannedClaims.forEach((name, pattern) {
        if (pattern.hasMatch(text)) offending.add('${file.path}: "$name"');
      });
    }
    expect(offending, isEmpty);
  });

  test('Income Guardian copy says it uses the schedule the user enters', () {
    final l10n = AppLocalizationsEn();
    expect(l10n.whatIsIncomeGuardianAnswer, contains('schedule you enter'));
    expect(l10n.incomeGuardianFeatureSubtitle, contains('schedule'));
    expect(l10n.dashboardIncomeGuardianSubtitle, contains('schedule'));
  });

  test('the supported types answer leads with what InvTrack is built for', () {
    final answer = AppLocalizationsEn().whatInvestmentTypesSupportedAnswer;
    expect(answer, isNot(startsWith('InvTrack supports Stocks')));
    final order = [
      'Fixed Deposits',
      'P2P',
      'Bonds',
      'Chit Funds',
      'Gold',
      'Property',
    ].map(answer.indexOf).toList();
    expect(order, everyElement(greaterThanOrEqualTo(0)));
    expect(order, orderedEquals([...order]..sort()));
    expect(
      answer.indexOf('Fixed Deposits'),
      lessThan(answer.indexOf('Stocks')),
    );
    expect(answer, contains('money in and money back'));
  });
}
