/// Screen names sent with `screen_view`: one per screen, in snake_case.
///
/// Never a path or an id. `/investments/abc123` would put an investment id in
/// Analytics (CLAUDE.md rule 7) and split one screen into as many as there are
/// investments. Every `GoRoute` in `app_router.dart` takes its `name:` from
/// here, and so do the pages that `Navigator.push` opens in the funnel.
class AnalyticsScreens {
  // Routes of app_router.dart
  static const String overview = 'overview';
  static const String investments = 'investments';
  static const String investmentDetail = 'investment_detail';
  static const String addCashFlow = 'add_cash_flow';
  static const String goals = 'goals';
  static const String goalCreate = 'goal_create';
  static const String goalDetail = 'goal_detail';
  static const String reports = 'reports';
  static const String reportBuilder = 'report_builder';
  static const String settings = 'settings';
  static const String signIn = 'sign_in';
  static const String lock = 'lock';
  static const String onboarding = 'onboarding';
  static const String fire = 'fire';
  static const String fireSetup = 'fire_setup';
  static const String fireSettings = 'fire_settings';
  static const String portfolioHealth = 'portfolio_health';
  static const String incomeCalendar = 'income_calendar';
  static const String monthlyRecap = 'monthly_recap';

  // Pages opened with Navigator.push on the way to a first investment. The
  // screen that adds a cash flow is [addCashFlow] however it is opened.
  static const String addInvestment = 'add_investment';
  static const String bulkImport = 'bulk_import';
}
