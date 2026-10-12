// AppColors.onFill picks the colour of a label or icon painted on a fill: white
// or ink, whichever has the higher contrast ratio. It replaces a threshold on
// luminance (`computeLuminance() > 0.5`) that sent white onto fills where it
// reads 1.4:1 to 3.7:1.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';

import '../../helpers/contrast.dart';

const _ink = AppColors.neutral900Light;

void main() {
  test('a dark fill takes white and a bright one takes ink', () {
    expect(AppColors.onFill(const Color(0xFF2A70E3)), Colors.white);
    expect(AppColors.onFill(const Color(0xFF8555EF)), Colors.white);
    expect(AppColors.onFill(const Color(0xFF6B7280)), Colors.white);
    expect(AppColors.onFill(AppColors.successLight), Colors.white);
    expect(AppColors.onFill(Colors.black), Colors.white);

    expect(AppColors.onFill(const Color(0xFFFFD700)), _ink);
    expect(AppColors.onFill(const Color(0xFFF59E0B)), _ink);
    expect(AppColors.onFill(const Color(0xFF10B981)), _ink);
    expect(AppColors.onFill(const Color(0xFF9E9E9E)), _ink);
    expect(AppColors.onFill(AppColors.errorDark), _ink);
    expect(AppColors.onFill(Colors.white), _ink);
  });

  test('it is white or ink, whichever has the higher ratio, on every colour '
      'of a grid of the sRGB cube', () {
    var checked = 0;
    for (var r = 0; r < 256; r += 17) {
      for (var g = 0; g < 256; g += 17) {
        for (var b = 0; b < 256; b += 17) {
          final fill = Color.fromARGB(255, r, g, b);
          final chosen = AppColors.onFill(fill);
          final white = contrastRatio(Colors.white, fill);
          final ink = contrastRatio(_ink, fill);
          expect(chosen == Colors.white || chosen == _ink, isTrue);
          expect(
            contrastRatio(chosen, fill),
            closeTo(white > ink ? white : ink, 1e-9),
            reason: 'onFill(#${fill.toARGB32().toRadixString(16)})',
          );
          checked++;
        }
      }
    }
    expect(checked, 4096);
  });

  test('a mid-tone fill reaches 4.5:1 with neither, which is why the purple '
      'and blue fills of four investment types are deepened', () {
    // #8b5cf6 is white 4.23 and ink 4.13: the best of both is under 4.5.
    const purple = Color(0xFF8B5CF6);
    expect(contrastRatio(AppColors.onFill(purple), purple), lessThan(kMinText));
    expect(contrastRatio(Colors.white, purple), closeTo(4.23, 0.01));
    expect(contrastRatio(_ink, purple), closeTo(4.13, 0.01));
  });
}
