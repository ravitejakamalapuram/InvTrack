import 'package:flutter/material.dart';

/// Width of [text] on one line in [style], as a [Text] there draws it: the
/// same inherited style, text scaler and bold-text setting.
///
/// Use it to decide a layout before it is built, such as whether a badge fits
/// beside a figure. Money values are measured on what is drawn, so privacy
/// mode must pass the dots it draws instead of the amount.
double measureTextWidth(BuildContext context, String text, TextStyle style) {
  var effective = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: effective),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
