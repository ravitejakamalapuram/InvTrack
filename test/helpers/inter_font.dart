import 'package:flutter/services.dart';

/// Registers the bundled Inter under the family names the app's text styles
/// ask for, so a widget test lays text out at phone widths. Without it the test
/// font (Ahem) is about 1.7 times wider and every width and overflow check
/// measures the wrong thing. Plus Jakarta Sans, the headline font, has no usable
/// file here, so Inter stands in for it too. Call it from setUpAll.
Future<void> loadInterFont() async {
  const inter = {
    'regular': 'Inter-Regular',
    '500': 'Inter-Medium',
    '600': 'Inter-SemiBold',
  };
  for (final (family, file) in [
    for (final MapEntry(:key, :value) in inter.entries) ('Inter_$key', value),
    ('Inter', 'Inter-Regular'),
    // google_fonts names the headline weights like this; Inter has three.
    ('PlusJakartaSans_regular', 'Inter-Regular'),
    ('PlusJakartaSans_500', 'Inter-Medium'),
    ('PlusJakartaSans_600', 'Inter-SemiBold'),
    ('PlusJakartaSans_700', 'Inter-SemiBold'),
    ('PlusJakartaSans_800', 'Inter-SemiBold'),
  ]) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('assets/fonts/$file.ttf'));
    await loader.load();
  }
}
