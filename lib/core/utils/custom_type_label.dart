import 'package:flutter/widgets.dart' show StringCharacters;

/// Cleaning and comparing the free text of a custom investment type (#936).
///
/// One definition of "the same label" for the form, the notifiers and import,
/// so a variant typed in a different case or with stray spaces never makes a
/// second type.
abstract final class CustomTypeLabel {
  /// Longest label, in characters the user sees (grapheme clusters).
  static const int maxLength = 40;

  /// Most active (not removed) custom types an account can hold.
  static const int maxActiveDefinitions = 50;

  // Zero-width characters (U+200B-200D, U+2060-2064, U+FEFF) and bidi
  // controls (U+200E-200F, U+202A-202E, U+2066-2069, U+061C). Dropped, not
  // replaced by a space: they are invisible, so they cannot tell two labels
  // apart.
  static final RegExp _zeroWidthAndBidi = RegExp(
    '[\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\u061C\uFEFF]',
  );

  // Whitespace as Dart's `\s` knows it, plus "next line" (U+0085), which is a
  // control character but separates words.
  static final RegExp _whitespace = RegExp(r'[\s\u0085]+');

  // Control characters left once whitespace has become spaces.
  static final RegExp _control = RegExp('[\u0000-\u001F\u007F-\u009F]');

  static final RegExp _spaces = RegExp(' {2,}');

  /// [raw] as it is stored and shown: invisible characters are dropped,
  /// whitespace runs become one space and the ends are trimmed. The casing
  /// the user typed is kept. Empty for null or blank input, which means "no
  /// custom type".
  static String clean(String? raw) {
    if (raw == null) return '';
    return raw
        .replaceAll(_zeroWidthAndBidi, '')
        .replaceAll(_whitespace, ' ')
        .replaceAll(_control, '')
        .replaceAll(_spaces, ' ')
        .trim();
  }

  /// The comparison key of a [clean]ed label: lower-cased with Dart's
  /// locale-independent `toLowerCase`, so it is the same on every device.
  static String keyOf(String cleaned) => cleaned.toLowerCase();

  /// Whether a [clean]ed label is longer than [maxLength].
  static bool exceedsMaxLength(String cleaned) =>
      cleaned.characters.length > maxLength;
}
