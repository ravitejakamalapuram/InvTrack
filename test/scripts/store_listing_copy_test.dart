// Tests for the Play listing copy in android/fastlane/metadata/android
// (review ticket A51, findings MKT-04 and MKT-05). The length limits and
// banned claims are checked by scripts/check_store_listing.sh and its tests in
// check_store_listing_test.dart; these tests pin what the copy must say.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';

const _listing = 'android/fastlane/metadata/android/en-US';

/// Reads a listing file without the trailing newline, which Play ignores.
String _read(String file) =>
    File('$_listing/$file').readAsStringSync().trimRight();

/// Characters as Play counts them (code points, not UTF-16 units).
int _chars(String text) => text.runes.length;

/// A currency-count claim such as "40+ currencies", "forty currencies" or
/// "40-plus currencies", in digits or number words, in any case.
final _currencyCount = RegExp(
  r'\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|'
  r'thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|'
  r'thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred)'
  r'(\+|-plus|\s+plus)?\s+currencies',
  caseSensitive: false,
);

void main() {
  test('title leads with FD and P2P instead of a generic head term', () {
    final title = _read('title.txt');
    expect(title, 'InvTrack: FD & P2P Tracker');
    expect(_chars(title), 26);
  });

  test('short description names the asset types and XIRR', () {
    final short = _read('short_description.txt');
    expect(
      short,
      'Track FDs, P2P lending, bonds, chit funds & gold in one app. '
      'True XIRR returns.',
    );
    expect(_chars(short), 79);
    expect(short, isNot(contains('MOIC')));
  });

  group('currency-count guard', () {
    test('matches counts in digits or words, with or without plus', () {
      for (final claim in [
        '40+ currencies',
        '16 currencies',
        'forty currencies',
        'Forty Currencies',
        '40-plus currencies',
        '40 plus currencies',
        'forty-plus currencies',
        'twenty-five currencies',
      ]) {
        expect(claim, matches(_currencyCount), reason: claim);
      }
    });

    test('ignores currency wording without a count', () {
      for (final text in [
        'Record each investment in its own currency',
        'Totals are converted to your base currency',
        'multi-currency support for major currencies',
      ]) {
        expect(text, isNot(matches(_currencyCount)), reason: text);
      }
    });
  });

  test('README claims no currency count the app does not offer', () {
    expect(
      File('README.md').readAsStringSync(),
      isNot(matches(_currencyCount)),
    );
  });

  // MKT-04: app-metadata.json held a stale copy of the listing (title
  // 'inv_tracker', a short description cut off mid-word). The fastlane files
  // are the only listing text; the metadata file must say so and must not
  // carry a second copy that can drift.
  test(
    'app-metadata.json points at the fastlane listing and holds no copy',
    () {
      final metadata =
          jsonDecode(File('app-metadata.json').readAsStringSync())
              as Map<String, dynamic>;
      final listings = (metadata['modules'] as List)
          .cast<Map<String, dynamic>>()
          .map((m) => m['playStoreListing'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .toList();
      expect(listings, hasLength(1));
      final listing = listings.single;
      expect(listing['authoritative'], isFalse);
      expect(listing['listingSource'], _listing);
      expect(
        Directory(listing['listingSource'] as String).existsSync(),
        isTrue,
      );
      for (final key in ['title', 'shortDescription', 'fullDescription']) {
        expect(listing.containsKey(key), isFalse, reason: key);
      }
    },
  );

  group('full description', () {
    late String full;

    setUp(() => full = _read('full_description.txt'));

    test('opens with a hook of at most 170 characters', () {
      final hook = full.split('\n\n').first;
      expect(_chars(hook), lessThanOrEqualTo(170), reason: hook);
      for (final term in [
        'fixed deposits',
        'P2P lending',
        'bonds',
        'chit funds',
        'XIRR',
      ]) {
        expect(hook, contains(term));
      }
    });

    test('follows the outline, in order, with CAPS headings', () {
      const headings = [
        'WHAT YOU CAN TRACK',
        'REAL RETURNS, WORKED OUT FOR YOU',
        'NEVER MISS A PAYOUT',
        "GOALS AND FIRE IN TODAY'S RUPEES",
        'MADE FOR INDIA, WORKS GLOBALLY',
        'DATA IN AND OUT',
        'PRIVACY AND SECURITY',
        'WHAT INVTRACK IS NOT',
        'START IN 10 SECONDS',
      ];
      final lines = full.split('\n');
      var last = -1;
      for (final heading in headings) {
        final index = lines.indexOf(heading);
        expect(
          index,
          greaterThan(last),
          reason: '"$heading" missing or out of order',
        );
        last = index;
      }
    });

    test('drops the box-drawing dividers', () {
      expect(full, isNot(contains('━')));
    });

    test('mentions the features the old copy left out', () {
      for (final phrase in [
        'Invoice discounting',
        'FIRE number',
        'CSV file',
        'PIN or fingerprint',
        'Continue as Guest',
        'its own currency',
        'lakh and crore',
      ]) {
        expect(full, contains(phrase));
      }
    });

    test('says what InvTrack is not', () {
      expect(full, contains('Not a broker.'));
      expect(full, contains('Not an investment adviser.'));
      expect(full, contains('No bank or SMS access.'));
    });

    test('keeps the accurate data-handling wording', () {
      expect(full, contains('Google Firebase'));
      expect(full, contains('after first sign-in'));
      expect(full, contains('Attached documents stay on your phone.'));
    });

    test('claims no currency count the app does not offer', () {
      // The per-investment picker offers 16 currencies and the base-currency
      // picker 14, so a "40+ currencies" style claim would be false.
      expect(full, isNot(matches(_currencyCount)));
    });

    test('worked example matches the app XIRR for a one-year FD', () {
      final xirr = XirrSolver.calculateXirr(
        [DateTime(2025, 4, 1), DateTime(2026, 4, 1)],
        [-100000, 107100],
      );
      expect(xirr, closeTo(0.071, 1e-6));
      expect(full, contains('₹1,00,000'));
      expect(full, contains('₹1,07,100'));
      expect(full, contains('1 April 2025'));
      expect(full, contains('1 April 2026'));
      expect(full, contains('7.1% a year'));
    });

    test('worked example matches the app XIRR for the six-month case', () {
      // 1 Apr 2025 to 1 Oct 2025 is 183 days; actual/365 like Excel.
      final expected = math.pow(1.071, 365 / 183) - 1;
      final xirr = XirrSolver.calculateXirr(
        [DateTime(2025, 4, 1), DateTime(2025, 10, 1)],
        [-100000, 107100],
      );
      expect(expected, closeTo(0.146611, 1e-6));
      expect(xirr, closeTo(expected, 1e-6));
      expect(full, contains('1 October 2025'));
      expect(full, contains('about 14.7% a year'));
    });
  });
}
