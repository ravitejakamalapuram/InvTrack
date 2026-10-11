// The screens that float an add button over a scroll body, and the label the
// geometry guard (layout_guard_harness.dart) measures each one under.
//
// test/repo/fab_clearance_scan_test.dart fails when a screen declares a floating
// action button and is not listed here, and the guard fails when a listed
// screen has no clearance measurement. So a new screen with a button cannot
// ship without a geometry check of its own.
const guardedFabScreens = <String, String>{
  'lib/features/overview/presentation/screens/overview_screen.dart': 'Overview',
  'lib/features/goals/presentation/screens/goals_screen.dart': 'Goals',
  'lib/features/investment/presentation/screens/investment_list_screen.dart':
      'Investments',
  'lib/features/investment/presentation/screens/investment_detail_screen.dart':
      'Detail',
};
