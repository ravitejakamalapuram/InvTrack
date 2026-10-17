/// English localizations whose privacy wording is a sentinel, so a test fails
/// when a screen reads hard-coded English instead of the translation.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/l10n/generated/app_localizations_en.dart';

const sentinelHiddenAmount = 'HIDDEN-AMOUNT-L10N';
const sentinelHiddenPercentage = 'HIDDEN-PERCENTAGE-L10N';

class _SentinelLocalizations extends AppLocalizationsEn {
  @override
  String get hiddenAmount => sentinelHiddenAmount;

  @override
  String get hiddenPercentage => sentinelHiddenPercentage;
}

class _SentinelDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SentinelDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(_SentinelLocalizations());

  @override
  bool shouldReload(_SentinelDelegate old) => false;
}

/// The sentinel delegate first, then the production ones for everything else.
const List<LocalizationsDelegate<dynamic>> sentinelLocalizationsDelegates = [
  _SentinelDelegate(),
  ...AppLocalizations.localizationsDelegates,
];
