import 'package:flutter/widgets.dart';

/// How much the user's text size setting enlarges body text, as a factor
/// (1.0 = no scaling).
///
/// Android 14 scales small text more than large text, so this reads the scaler
/// at a body size instead of a single factor. Use it to size boxes that must
/// grow with the text, such as a carousel page or a column minimum width.
double textScaleOf(BuildContext context) {
  const probe = 14.0;
  return MediaQuery.textScalerOf(context).scale(probe) / probe;
}
