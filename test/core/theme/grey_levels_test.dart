// The grey text levels stay apart.
//
// Darkening the light greys to pass 4.5:1 squeezes them toward one another, and
// the contrast guard cannot see that: it passes if every grey is readable, even
// when two have become the same colour. Muted text (neutral500) and subtle text
// (neutral400) tell a caption from a hint, so each step must stay a step.
//
// 1.2:1 sits just under today's smallest step (1.22:1, muted to subtle, which
// is about 5 apart in CIEDE2000, a clear difference side by side). A new value
// that closes the gap further fails here, whatever its own contrast is.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';

import '../../helpers/contrast.dart';

const _minStep = 1.2;

void main() {
  test('light greys step down from secondary to muted to subtle', () {
    final secondary = AppColors.neutral600Light;
    final muted = AppColors.neutral500Light;
    final subtle = AppColors.neutral400Light;
    expect(
      secondary.computeLuminance(),
      lessThan(muted.computeLuminance()),
      reason: 'secondary is the darkest',
    );
    expect(muted.computeLuminance(), lessThan(subtle.computeLuminance()));
    expect(
      subtle.computeLuminance(),
      lessThan(AppColors.cardLight.computeLuminance()),
      reason: 'subtle is still darker than the card it sits on',
    );
    expect(
      contrastRatio(secondary, muted),
      greaterThanOrEqualTo(_minStep),
      reason: 'secondary to muted',
    );
    expect(
      contrastRatio(muted, subtle),
      greaterThanOrEqualTo(_minStep),
      reason: 'muted to subtle',
    );
  });

  test('dark greys step down from secondary to muted', () {
    final secondary = AppColors.neutral400Dark;
    final muted = AppColors.neutral500Dark;
    expect(
      secondary.computeLuminance(),
      greaterThan(muted.computeLuminance()),
      reason: 'secondary is the lighter on a dark ground',
    );
    expect(
      muted.computeLuminance(),
      greaterThan(AppColors.cardDark.computeLuminance()),
    );
    expect(
      contrastRatio(secondary, muted),
      greaterThanOrEqualTo(_minStep),
      reason: 'secondary to muted',
    );
  });

  test('textSecondaryLight follows muted', () {
    expect(AppColors.textSecondaryLight, AppColors.neutral500Light);
  });
}
