// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'InvTrack';

  @override
  String get overview => 'Overview';

  @override
  String get investments => 'Investments';

  @override
  String get goals => 'Goals';

  @override
  String get settings => 'Settings';

  @override
  String get currency => 'Currency';

  @override
  String get selectCurrency => 'Select Currency';

  @override
  String get locale => 'Language & Region';

  @override
  String get dateFormat => 'Date Format';

  @override
  String get today => 'today';

  @override
  String get yesterday => 'yesterday';

  @override
  String daysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String weeksAgo(int count) {
    return '$count weeks ago';
  }

  @override
  String monthsAgo(int count) {
    return '$count months ago';
  }

  @override
  String yearsAgo(int count) {
    return '$count years ago';
  }

  @override
  String get notesLabel => 'Notes';

  @override
  String get signIn => 'Sign In';

  @override
  String get signOut => 'Sign Out';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get done => 'Done';

  @override
  String get skip => 'Skip';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeDescription => 'Choose how InvTrack looks';

  @override
  String get themeSystem => 'System';

  @override
  String get themeSystemSubtitle => 'Match device settings';

  @override
  String get themeLight => 'Light';

  @override
  String get themeLightSubtitle => 'Always use light theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeDarkSubtitle => 'Always use dark theme';

  @override
  String get preview => 'Preview';

  @override
  String get primary => 'Primary';

  @override
  String get success => 'Success';

  @override
  String get errorColor => 'Error';

  @override
  String get general => 'General';

  @override
  String get security => 'Security';

  @override
  String get appLock => 'App Lock';

  @override
  String get pinEnabled => 'PIN enabled';

  @override
  String get biometricsOn => 'Biometrics on';

  @override
  String get protectYourData => 'Protect your data';

  @override
  String get notifications => 'Notifications';

  @override
  String get remindersAndSummaries => 'Reminders & summaries';

  @override
  String get dataAndAccount => 'Data & Account';

  @override
  String get importExportBackupDelete => 'Import, export, backup & delete';

  @override
  String get about => 'About';

  @override
  String get aboutInvTrack => 'About InvTrack';

  @override
  String get versionLegalSupport => 'Version, legal & support';

  @override
  String get signOutConfirmTitle => 'Sign Out';

  @override
  String get signOutConfirmMessage => 'Are you sure you want to sign out?';

  @override
  String get notificationsSectionTitle => 'Notifications';

  @override
  String get summaries => 'Summaries';

  @override
  String get periodicUpdatesAboutPortfolio =>
      'Periodic updates about your portfolio performance';

  @override
  String get weeklySummary => 'Weekly Summary';

  @override
  String get getSummaryEverySunday => 'Get a summary every Sunday';

  @override
  String get monthlySummary => 'Monthly Summary';

  @override
  String get endOfMonthIncomeRecap => 'End of month income recap';

  @override
  String get reminders => 'Reminders';

  @override
  String get stayOnTopOfUpcomingEvents => 'Stay on top of upcoming events';

  @override
  String get incomeReminders => 'Income Reminders';

  @override
  String get whenIncomeIsExpected => 'When income is expected';

  @override
  String get maturityReminders => 'Maturity Reminders';

  @override
  String get beforeInvestmentsMature => 'Before investments mature';

  @override
  String get goalMilestones => 'Goal Milestones';

  @override
  String get celebrateAtMilestones => 'Celebrate at 25%, 50%, 75%, 100%';

  @override
  String get debug => 'Debug';

  @override
  String get testNotification => 'Test Notification';

  @override
  String get sendImmediateTest => 'Send an immediate test';

  @override
  String get testNotificationSent => 'Test notification sent!';

  @override
  String get permissionDenied => 'Permission denied';

  @override
  String get scheduledTest => 'Scheduled Test';

  @override
  String get notifyInFiveSeconds => 'Notify in 5 seconds';

  @override
  String get scheduledForFiveSeconds => 'Scheduled for 5 seconds';

  @override
  String get securityTitle => 'Security';

  @override
  String get appLockSection => 'App Lock';

  @override
  String get yourAppIsProtectedWithPin => 'Your app is protected with a PIN';

  @override
  String get addPinToProtectData => 'Add a PIN to protect your data';

  @override
  String get enableAppLock => 'Enable App Lock';

  @override
  String get pinRequiredToOpenApp => 'PIN required to open app';

  @override
  String get protectWithFourDigitPin => 'Protect with a 4-digit PIN';

  @override
  String get quickUnlock => 'Quick Unlock';

  @override
  String get useBiometricsForFasterAccess => 'Use biometrics for faster access';

  @override
  String get faceIdTouchId => 'Face ID / Touch ID';

  @override
  String get unlockWithBiometrics => 'Unlock with biometrics';

  @override
  String get enableBiometricUnlock => 'Enable Biometric Unlock?';

  @override
  String get useFingerprintOrFaceForFasterAccess =>
      'Use fingerprint or face recognition for faster access to your app.';

  @override
  String get notNow => 'Not Now';

  @override
  String get enable => 'Enable';

  @override
  String get biometricUnlockEnabled => 'Biometric unlock enabled';

  @override
  String get managePin => 'Manage PIN';

  @override
  String get changePin => 'Change PIN';

  @override
  String get updateYourSecurityCode => 'Update your security code';

  @override
  String get dataStoredLocallyMessage =>
      'Your investment data is stored locally on this device and is never uploaded to external servers.';

  @override
  String get helpFaqTitle => 'Help & FAQ';

  @override
  String get gettingStarted => 'Getting Started';

  @override
  String get howToAddFirstInvestment => 'How do I add my first investment?';

  @override
  String get howToAddFirstInvestmentAnswer =>
      'Tap the \"+\" button on the Investments tab. Enter your investment details including name, amount, date, and category. You can also add transactions later to track your investment growth.';

  @override
  String get whatInvestmentTypesSupported =>
      'What investment types are supported?';

  @override
  String get whatInvestmentTypesSupportedAnswer =>
      'InvTrack supports Stocks, Mutual Funds, Fixed Deposits, Gold, Real Estate, Crypto, and more. You can categorize any investment type.';

  @override
  String get trackingReturns => 'Tracking Returns';

  @override
  String get howAreReturnsCalculated => 'How are returns calculated?';

  @override
  String get howAreReturnsCalculatedAnswer =>
      'InvTrack uses XIRR (Extended Internal Rate of Return) to calculate accurate returns considering all your transactions and their timing. This gives you a true picture of your investment performance.';

  @override
  String get whatIsXirr => 'What is XIRR?';

  @override
  String get whatIsXirrAnswer =>
      'XIRR is the industry-standard method for calculating returns on investments with multiple cash flows at different times. It accounts for when you invested and when you withdrew money.';

  @override
  String get goalsSection => 'Goals';

  @override
  String get howToSetFinancialGoal => 'How do I set a financial goal?';

  @override
  String get howToSetFinancialGoalAnswer =>
      'Go to the Goals tab and tap \"+\". Enter your goal name, target amount, and deadline. InvTrack will track your progress and show how much you need to save.';

  @override
  String get canLinkInvestmentsToGoals => 'Can I link investments to goals?';

  @override
  String get canLinkInvestmentsToGoalsAnswer =>
      'Yes! When creating or editing a goal, you can allocate specific investments toward that goal. This helps you track progress toward multiple goals simultaneously.';

  @override
  String get privacyAndSecurity => 'Privacy & Security';

  @override
  String get isMyDataSecure => 'Is my data secure?';

  @override
  String get isMyDataSecureAnswer =>
      'Yes! All your data is stored securely in Firebase with encryption. You can also enable app lock with PIN or biometrics for extra security.';

  @override
  String get whatIsPrivacyMode => 'What is Privacy Mode?';

  @override
  String get whatIsPrivacyModeAnswer =>
      'Privacy Mode hides all financial amounts in the app, showing \"•••••\" instead. Perfect for when you want to check your portfolio in public. Toggle it from Settings → Appearance.';

  @override
  String get dataManagementSection => 'Data Management';

  @override
  String get canExportMyData => 'Can I export my data?';

  @override
  String get canExportMyDataAnswer =>
      'Yes! Go to Settings → Data & Account → Export Data. You can download all your investment data as a ZIP file containing CSV files.';

  @override
  String get howToBackupData => 'How do I backup my data?';

  @override
  String get howToBackupDataAnswer =>
      'Your data is automatically backed up to Firebase when you\'re signed in. You can also export a local backup anytime from Settings → Data & Account.';

  @override
  String get multiCurrencySupport => 'Multi-Currency Support';

  @override
  String get canChangeMyCurrency => 'Can I change my currency?';

  @override
  String get canChangeMyCurrencyAnswer =>
      'Yes! Go to Settings → Currency and select from 40+ supported currencies. The app will format all amounts according to your selected currency and locale.';

  @override
  String get howDoesCurrencyFormattingWork =>
      'How does currency formatting work?';

  @override
  String get howDoesCurrencyFormattingWorkAnswer =>
      'InvTrack automatically formats numbers based on your currency:\n• Indian Rupee (₹): Shows 1L, 10L, 1Cr\n• USD/EUR/GBP: Shows 100K, 1M, 10M\n• Other currencies use appropriate locale formatting';

  @override
  String get needMoreHelpContact =>
      'Need more help? Contact support@invtracker.com';

  @override
  String get incomeGuardianSection => 'Income Guardian';

  @override
  String get whatIsIncomeGuardian => 'What is Income Guardian?';

  @override
  String get whatIsIncomeGuardianAnswer =>
      'Income Guardian is an AI-powered income monitoring system that predicts when you should receive payments from your investments, tracks platform reliability, and alerts you to missed or delayed income. It transforms InvTrack from passive tracking to active wealth protection.';

  @override
  String get howDoesIncomeProjectionWork => 'How does income projection work?';

  @override
  String get howDoesIncomeProjectionWorkAnswer =>
      'Income Guardian uses Weighted Moving Average (WMA) machine learning to predict your next payment amount based on your last 6 payments. It learns platform-specific payment delays (e.g., LenDenClub pays 2 days late) and adjusts expectations automatically. For stable payments, it applies ±8% tolerance; for volatile payments, tolerance expands to match historical variance.';

  @override
  String get whatIsIncomeTrendAnalysis => 'What is Income Trend Analysis?';

  @override
  String get whatIsIncomeTrendAnalysisAnswer =>
      'Income Trend Analysis provides month-over-month (MoM) and quarter-over-quarter (QoQ) growth metrics, platform reliability scores, and auto-generated insights. It helps you track income growth, identify unreliable platforms, and optimize your portfolio for consistent cash flow.';

  @override
  String get whatIsHHIScore =>
      'What is the HHI (Herfindahl-Hirschman Index) score?';

  @override
  String get whatIsHHIScoreAnswer =>
      'HHI measures income concentration risk. A score of 1.0 means all income comes from one platform (maximum risk). A score of 0.33 means income is evenly distributed across 3+ platforms (well-diversified). Lower scores indicate better diversification and reduced risk of income loss from a single platform failure.';

  @override
  String get whatIsPlatformReliability => 'What is Platform Reliability Score?';

  @override
  String get whatIsPlatformReliabilityAnswer =>
      'Platform Reliability Score (0-100%) measures how consistently a platform pays on time and with the expected amount. Scores ≥80% are excellent (green), 60-80% are acceptable (yellow), and <60% indicate frequent delays or payment issues (red). This helps you identify which platforms are most reliable for your income.';

  @override
  String get incomeGuardianSettings => 'Income Guardian';

  @override
  String get incomeGuardianGeneral => 'General';

  @override
  String get enableIncomeGuardian =>
      'Enable automated income tracking and payment notifications';

  @override
  String get incomeGuardianEnabled => 'Monitoring your expected payments';

  @override
  String get incomeGuardianDisabled => 'Tap to enable automated tracking';

  @override
  String get notificationTiming => 'Notification Timing';

  @override
  String get notificationTimingFooter =>
      'Configure when you want to be notified about expected payments';

  @override
  String get upcomingPaymentAlert => 'Upcoming Payment Alert';

  @override
  String upcomingPaymentAlertSubtitle(int days, String plural) {
    return '$days day$plural before expected date';
  }

  @override
  String get overduePaymentAlert => 'Overdue Payment Alert';

  @override
  String overduePaymentAlertSubtitle(int days, String plural) {
    return '$days day$plural after expected date';
  }

  @override
  String get autoMatching => 'Auto-Matching';

  @override
  String get autoMatchingFooter =>
      'Fine-tune how the system matches actual payments to expected payments';

  @override
  String get amountTolerance => 'Amount Tolerance';

  @override
  String amountToleranceSubtitle(int percent) {
    return '±$percent% variance allowed';
  }

  @override
  String get dateWindow => 'Date Window';

  @override
  String dateWindowSubtitle(int days, String plural) {
    return '±$days day$plural from expected date';
  }

  @override
  String get confidenceThreshold => 'Confidence Threshold';

  @override
  String confidenceThresholdSubtitle(int percent) {
    return '$percent% minimum match score';
  }

  @override
  String get platformDelays => 'Platform Delays';

  @override
  String get platformDelaysFooter =>
      'Customize expected delays for specific platforms (e.g., LenDenClub +2 days)';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get platformDelaysComingSoon =>
      'Platform-specific delay adjustments will be available in a future update';

  @override
  String get incomeStatusUpcoming => 'Upcoming';

  @override
  String get incomeStatusDueSoon => 'Due Soon';

  @override
  String get incomeStatusGracePeriod => 'Grace Period';

  @override
  String get incomeStatusOverdue => 'Overdue';

  @override
  String get incomeStatusReceived => 'Received';

  @override
  String get incomeStatusDismissed => 'Dismissed';

  @override
  String get calendarRefresh => 'Refresh';

  @override
  String get calendarLoadFailed => 'Failed to load calendar';

  @override
  String get calendarEmptyMessage => 'No expected payments this month';

  @override
  String get calendarFilterAllPayments => 'All Payments';

  @override
  String get calendarFilterPending => 'Pending';

  @override
  String get calendarFilterOverdue => 'Overdue';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarRetry => 'Retry';

  @override
  String get calendarNoInternet => 'No internet connection';

  @override
  String get dashboardIncomeGuardian => 'Income Guardian';

  @override
  String get dashboardNextExpected => 'Next Expected';

  @override
  String get dashboardAllCaughtUp => 'All caught up!';

  @override
  String get dashboardPending => 'Pending';

  @override
  String get dashboardOverdue => 'Overdue';

  @override
  String get dashboardLoadFailed => 'Failed to load income data';

  @override
  String get dashboardUnknownInvestment => 'Unknown';

  @override
  String get dashboardLoading => 'Loading...';

  @override
  String get calendarScreenEmptyAll => 'No Expected Payments';

  @override
  String get calendarScreenEmptyPending => 'No Pending Payments';

  @override
  String get calendarScreenEmptyOverdue => 'No Overdue Payments';

  @override
  String get calendarGridPreviousMonth => 'Previous month';

  @override
  String get calendarGridNextMonth => 'Next month';

  @override
  String get calendarGridInvestmentHeader => 'Investment';

  @override
  String get calendarGridUnknownInvestment => 'Unknown';

  @override
  String calendarGridExpectedCount(int count) {
    return '$count expected';
  }

  @override
  String get calendarGridPaymentDetails => 'Payment Details';

  @override
  String get calendarGridExpectedDate => 'Expected Date';

  @override
  String get calendarGridExpectedAmount => 'Expected Amount';

  @override
  String get calendarGridStatus => 'Status';

  @override
  String get calendarGridActualAmount => 'Actual Amount';

  @override
  String get calendarGridActualDate => 'Actual Date';

  @override
  String get howToAccessIncomeReports =>
      'How do I access Income Guardian reports?';

  @override
  String get howToAccessIncomeReportsAnswer =>
      'Income Trend reports are available in the Reports section. Navigate to Reports → Income Trend Analysis to see your monthly income trends, platform reliability scores, HHI diversification metrics, and auto-generated insights. Expected payment tracking will be available in the Dashboard (coming in Phase 2).';

  @override
  String get advancedFeatures => 'Advanced Features';

  @override
  String get howToEnableDebugMode => 'How do I enable debug mode?';

  @override
  String get howToEnableDebugModeAnswer =>
      'Tap the version number on the About screen 7 times within 3 seconds. This will reveal developer tools in Settings.';

  @override
  String get whatIsDebugModeFor => 'What is debug mode for?';

  @override
  String get whatIsDebugModeForAnswer =>
      'Debug mode provides advanced tools for developers and power users, including sample data management and app diagnostics. It is useful for testing features and troubleshooting issues.';

  @override
  String get howToDisableDebugMode => 'How do I disable debug mode?';

  @override
  String get howToDisableDebugModeAnswer =>
      'Tap the version number 7 times again, or toggle it off in Debug Settings under the Developer section in Settings.';

  @override
  String get invTrack => 'InvTrack';

  @override
  String version(String version, String buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get legal => 'Legal';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get support => 'Support';

  @override
  String get helpAndFaq => 'Help & FAQ';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get supportEmail => 'invtrack_support@googlegroups.com';

  @override
  String supportEmailSubject(String version) {
    return 'InvTrack Support Request (v$version)';
  }

  @override
  String get supportEmailBody => 'Please describe your issue or question:\n\n';

  @override
  String emailCopiedMessage(String email) {
    return 'Email copied to clipboard: $email';
  }

  @override
  String get ok => 'OK';

  @override
  String get errorLoadingAppInfo => 'Unable to load app information';

  @override
  String get retry => 'Retry';

  @override
  String signInFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get accountLinkedSuccessfully => 'Account linked successfully!';

  @override
  String linkingFailed(String error) {
    return 'Linking failed: $error';
  }

  @override
  String get debugModeActivationFailed => 'Failed to toggle debug mode';

  @override
  String get madeWithLove => 'Made with ❤️ for smart investors';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get exportReady => 'Export ready! Choose where to save.';

  @override
  String get importStrategy => 'Import Strategy';

  @override
  String get replaceAllData => 'Replace All Data?';

  @override
  String get replaceAllDataMessage =>
      'This will DELETE all existing investments, goals, and documents and replace them with the imported data. This cannot be undone.';

  @override
  String get replaceAll => 'Replace All';

  @override
  String importCompletedWithErrors(String error) {
    return 'Import completed with errors: $error';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get seedDemoData => 'Seed Demo Data?';

  @override
  String get seedDemoDataMessage =>
      'This will add 10 sample investments with realistic cash flows and goals. Great for testing!';

  @override
  String get seedData => 'Seed Data';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountMessage =>
      'This will permanently delete:\n\n• All investments & cash flows\n• All goals & progress\n• All documents & attachments\n• Your user profile\n\nThis action cannot be undone!';

  @override
  String get deleteEverything => 'Delete Everything';

  @override
  String get accountDeletionCancelled => 'Account deletion cancelled';

  @override
  String get accountDeletedSuccessfully => 'Account deleted successfully';

  @override
  String failedToDeleteAccount(String message) {
    return 'Failed to delete account: $message';
  }

  @override
  String error(String error) {
    return 'Error: $error';
  }

  @override
  String get finalConfirmation => 'Final Confirmation';

  @override
  String get typeDeleteToConfirm => 'Type DELETE to confirm:';

  @override
  String get deleteMyAccount => 'Delete My Account';

  @override
  String get mergeInvestments => 'Merge Investments';

  @override
  String mergeInvestmentsMessage(int count) {
    return 'Merge $count investments into one.';
  }

  @override
  String get merge => 'Merge';

  @override
  String get fireSettings => 'FIRE Settings';

  @override
  String get noFireSettingsFound => 'No FIRE settings found';

  @override
  String get setUpFire => 'Set Up FIRE';

  @override
  String get basicSettings => 'Basic Settings';

  @override
  String get advancedSettings => 'Advanced Settings';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get resetFireSettings => 'Reset FIRE Settings';

  @override
  String get startOverWithNewSettings => 'Start over with new settings';

  @override
  String yearsAge(int age) {
    return '$age years';
  }

  @override
  String get monthlyExpenses => 'Monthly Expenses';

  @override
  String get selectFireType => 'Select FIRE Type';

  @override
  String percentageValue(String value) {
    return '$value%';
  }

  @override
  String get resetFireSettingsConfirm => 'Reset FIRE Settings?';

  @override
  String get resetFireSettingsMessage =>
      'This will delete all your FIRE settings. You will need to set them up again.';

  @override
  String get reset => 'Reset';

  @override
  String get trySampleData => 'Try Sample Data';

  @override
  String get exploreWithRealisticInvestments =>
      'Explore with realistic Indian investments';

  @override
  String get tryIt => 'Try It';

  @override
  String get failedToLoadData => 'Failed to load data';

  @override
  String get pleaseTryAgainLater => 'Please try again later';

  @override
  String get connectionError => 'Connection Error';

  @override
  String get failedToLoadFireData =>
      'Failed to load FIRE data. Please try again.';

  @override
  String get failedToLoadFireSettings =>
      'Failed to load FIRE settings. Please try again.';

  @override
  String get failedToLoadInvestments => 'Failed to load investments';

  @override
  String get fireJourney => 'FIRE Journey';

  @override
  String get getStarted => 'Get Started';

  @override
  String get openInPdfViewer => 'Open in PDF Viewer';

  @override
  String get changeFile => 'Change File';

  @override
  String get permissionRequired => 'Permission Required';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get importInvestments => 'Import Investments';

  @override
  String get confirmImport => 'Confirm Import';

  @override
  String get goBack => 'Go Back';

  @override
  String get editGoal => 'Edit Goal';

  @override
  String get deleteGoal => 'Delete Goal';

  @override
  String get deleteGoalQuestion => 'Delete Goal?';

  @override
  String deleteGoalMessage(String goalName) {
    return 'This will permanently delete \"$goalName\".';
  }

  @override
  String get goalDeleted => 'Goal deleted';

  @override
  String get archiveGoalQuestion => 'Archive Goal?';

  @override
  String archiveGoalMessage(String goalName) {
    return '\"$goalName\" will be hidden from your active goals.';
  }

  @override
  String get goalArchived => 'Goal archived';

  @override
  String get unarchiveGoalQuestion => 'Unarchive Goal?';

  @override
  String unarchiveGoalMessage(String goalName) {
    return '\"$goalName\" will be restored to your active goals.';
  }

  @override
  String get goalRestored => 'Goal restored';

  @override
  String get noArchivedGoals => 'No Archived Goals';

  @override
  String get archivedGoalsAppearHere => 'Archived goals will appear here';

  @override
  String get failedToLoadGoals => 'Failed to load goals. Please try again.';

  @override
  String get viewActiveGoals => 'View active goals';

  @override
  String get filterActive => 'Active';

  @override
  String get filterArchived => 'Archived';

  @override
  String get filterAll => 'All';

  @override
  String get filterOpen => 'Open';

  @override
  String get filterClosed => 'Closed';

  @override
  String get createYourFirstGoal => 'Create Your First Goal';

  @override
  String get setYourFirstGoal => 'Set Your First Goal';

  @override
  String get trackProgressTowardsTargets =>
      'Track progress towards your financial targets';

  @override
  String goalsAchieved(int achieved, int total) {
    return '$achieved/$total achieved';
  }

  @override
  String get goalCompleted => 'Completed';

  @override
  String get updateNow => 'Update Now';

  @override
  String get addInvestment => 'Add Investment';

  @override
  String get clearSampleData => 'Clear Sample Data?';

  @override
  String get clear => 'Clear';

  @override
  String get keepSampleData => 'Keep Sample Data?';

  @override
  String get keep => 'Keep';

  @override
  String get invTrackerPremium => 'InvTracker Premium';

  @override
  String get maybeLater => 'Maybe Later';

  @override
  String get unlockPremiumFeature => 'Unlock Premium feature';

  @override
  String get signInTagline => 'Track investments. Grow wealth.';

  @override
  String get signInTermsText =>
      'By continuing, you agree to our Terms of Service\nand Privacy Policy';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get doubleTapHoldToCopy => 'Double tap and hold to copy exact amount';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get googleSignInInitFailure =>
      'Failed to initialize Google Sign-In. Please try again.';

  @override
  String get sampleDataLoaded => '🧪 Sample data loaded! Explore the app.';

  @override
  String get sampleDataLoadFailed =>
      'Failed to load sample data. Please try again.';

  @override
  String get downloadTemplate => 'Download';

  @override
  String get uploadCsv => 'Upload';

  @override
  String get typeValuesHeader => 'Type Values:';

  @override
  String get welcomeToPremium => 'Welcome to Premium!';

  @override
  String get upgradeForPrice => 'Upgrade for \$4.99/mo';

  @override
  String get goalEmoji => '🎯';

  @override
  String get documentDeleted => 'Document deleted';

  @override
  String get failedToDeleteDocument => 'Failed to delete document';

  @override
  String get couldNotAccessCamera => 'Could not access camera';

  @override
  String get couldNotAccessFiles => 'Could not access files';

  @override
  String documentsAdded(int count) {
    return '$count documents added';
  }

  @override
  String yearsFormat(int age) {
    return '$age years';
  }

  @override
  String percentageFormat(String value) {
    return '$value%';
  }

  @override
  String get addDocument => 'Add Document';

  @override
  String get addTransaction => 'Add Transaction';

  @override
  String get templateReadyToShare => 'Template ready to share/save';

  @override
  String get failedToCreateTemplate => 'Failed to create template';

  @override
  String get deleteTransaction => 'Delete Transaction?';

  @override
  String get deleteInvestment => 'Delete Investment?';

  @override
  String get deleteInvestmentMessage =>
      'This will permanently delete this investment and all its transactions. This action cannot be undone.';

  @override
  String get investmentDeleted => 'Investment deleted';

  @override
  String get failedToDeleteInvestment => 'Failed to delete investment';

  @override
  String get fileNotFound =>
      'File not found. It may have been moved or deleted.';

  @override
  String deleteInvestmentsCount(int count, String plural) {
    return 'Delete $count Investment$plural?';
  }

  @override
  String get actionCannotBeUndone => 'This action cannot be undone.';

  @override
  String deleteGoalsCount(int count, String plural) {
    return 'Delete $count Goal$plural?';
  }

  @override
  String deleteGoalsMessage(String plural) {
    return 'This action cannot be undone. The selected goal$plural will be permanently deleted.';
  }

  @override
  String get deleteDocument => 'Delete Document?';

  @override
  String deleteDocumentMessage(String name) {
    return 'Are you sure you want to delete \"$name\"? This cannot be undone.';
  }

  @override
  String get tooltipBack => 'Back';

  @override
  String get tooltipClose => 'Close';

  @override
  String get tooltipGoBack => 'Go back';

  @override
  String get tooltipCloseSetup => 'Close setup';

  @override
  String get tooltipFireSettings => 'FIRE Settings';

  @override
  String get tooltipDecreaseAge => 'Decrease age';

  @override
  String get tooltipIncreaseAge => 'Increase age';

  @override
  String get tooltipDecreaseTargetAge => 'Decrease target age';

  @override
  String get tooltipIncreaseTargetAge => 'Increase target age';

  @override
  String get tooltipClearTargetDate => 'Clear target date';

  @override
  String get tooltipEditGoal => 'Edit Goal';

  @override
  String get tooltipExitSelection => 'Exit selection';

  @override
  String get tooltipSelectGoals => 'Select goals';

  @override
  String get tooltipAddGoal => 'Add Goal';

  @override
  String selectGoalSemanticLabel(String goalName) {
    return 'Select $goalName';
  }

  @override
  String viewGoalDetailsSemanticLabel(String goalName) {
    return 'View details for $goalName';
  }

  @override
  String get tooltipMoreOptions => 'More options';

  @override
  String get tooltipShareDocument => 'Share document';

  @override
  String get tooltipToggleInformation => 'Toggle information';

  @override
  String get documentViewerContentLabel => 'Document content';

  @override
  String get documentViewerResetZoomHint => 'Double tap to reset zoom';

  @override
  String get documentViewerResetZoomAction => 'Reset zoom';

  @override
  String documentSemanticLabel(String name) {
    return 'Document: $name';
  }

  @override
  String pdfDocumentLabel(String name) {
    return 'PDF document: $name';
  }

  @override
  String get tooltipSearchInvestments => 'Search investments';

  @override
  String get tooltipClearText => 'Clear text';

  @override
  String get tooltipClearStartDate => 'Clear start date';

  @override
  String get tooltipClearMaturityDate => 'Clear maturity date';

  @override
  String get hintNoMaturityDateSet => 'No maturity date set';

  @override
  String get semanticSelectTransactionDate => 'Select transaction date';

  @override
  String get hintSearch => 'Search...';

  @override
  String get hintDeleteConfirmation => 'DELETE';

  @override
  String get hintWhenDidYouInvest => 'When did you invest?';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get saving => 'Saving...';

  @override
  String saveMultipleFiles(int count) {
    return 'Save $count Files';
  }

  @override
  String get appLockEnabled => 'App Lock enabled';

  @override
  String get fileNotFoundError => 'File not found.';

  @override
  String errorOpeningFile(String message) {
    return 'Error opening file: $message';
  }

  @override
  String failedToShareDocument(String error) {
    return 'Failed to share document: $error';
  }

  @override
  String investmentsMerged(String name) {
    return 'Investments merged into \"$name\"';
  }

  @override
  String get debugMode => 'Debug Mode';

  @override
  String get debugSettings => 'Debug Settings';

  @override
  String get advancedToolsAndDiagnostics => 'Advanced tools & diagnostics';

  @override
  String get enableDebugMode => 'Enable Debug Mode';

  @override
  String get debugModeEnabled => '🛠️ Debug mode enabled';

  @override
  String get debugModeDisabled => 'Debug mode disabled';

  @override
  String get debugModeDescription => 'Show developer tools and diagnostics';

  @override
  String get appInfo => 'App Info';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get developer => 'Developer';

  @override
  String get sampleData => 'Sample Data';

  @override
  String get confirmClearSampleData =>
      'Are you sure you want to delete all sample data?';

  @override
  String get sampleDataCleared => 'Sample data cleared successfully';

  @override
  String get tapVersionToEnable => 'Tap version 7 times to enable debug mode';

  @override
  String get appVersion => 'App Version';

  @override
  String get buildNumber => 'Build Number';

  @override
  String get platform => 'Platform';

  @override
  String get deviceInfo => 'Device Info';

  @override
  String get addSampleInvestments => 'Add sample investments';

  @override
  String get deleteSampleInvestments =>
      'Delete all sample investments and goals';

  @override
  String get viewAppInformation => 'View app version and device details';

  @override
  String get sampleDataSeeded => 'Sample data added successfully';

  @override
  String get close => 'Close';

  @override
  String get noSampleDataToClear => 'No sample data to clear';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get guestModeNotice =>
      'Your data is saved to the cloud as a guest. Sign in to secure it across devices — uninstalling the app may cause data loss.';

  @override
  String get guestModeIndicator => 'Guest Mode (Anonymous Account)';

  @override
  String get signInToBackup => 'Sign In to Link Account';

  @override
  String get deleteGuestData => 'Delete Guest Data';

  @override
  String get deleteGuestDataConfirm =>
      'Are you sure? This will permanently delete all your data from cloud and local storage, and remove your anonymous account.';

  @override
  String get guestDataDeleted =>
      'Guest data and anonymous account deleted successfully';

  @override
  String get guestDataDeletionFailed =>
      'Failed to delete guest data. Please try again.';

  @override
  String get guestModeSection => 'Guest Mode';

  @override
  String get whatIsGuestMode => 'What is Guest Mode?';

  @override
  String get whatIsGuestModeAnswer =>
      'Guest Mode lets you use InvTrack without signing in. Your data is stored in the cloud under an anonymous account, so you can access it across devices. You can sign in later to link this data to your Google account.';

  @override
  String get howToLinkGuestAccount =>
      'How do I link my guest account to Google?';

  @override
  String get howToLinkGuestAccountAnswer =>
      'Tap the \'Sign In to Link Account\' button in Settings. If your Google account already exists, we\'ll create a backup of your guest data first, then you can import it after signing in.';

  @override
  String get whatHappensToGuestData =>
      'What happens to my guest data when I sign in?';

  @override
  String get whatHappensToGuestDataAnswer =>
      'If your Google account is new, your guest data is automatically linked to it. If your Google account already exists, we create a ZIP backup of your guest data, which you can import to merge with your existing data.';

  @override
  String get loading => 'Loading...';

  @override
  String currencySwitchedSuccessfully(String currency) {
    return 'Currency switched to $currency';
  }

  @override
  String currencySwitchFailed(String currency) {
    return 'Failed to switch to $currency. Please try again.';
  }

  @override
  String loadingProgress(int fetched, int total) {
    return 'Loading: $fetched of $total';
  }

  @override
  String get currencyUSD => 'US Dollar (\$)';

  @override
  String get currencyEUR => 'Euro (€)';

  @override
  String get currencyGBP => 'British Pound (£)';

  @override
  String get currencyINR => 'Indian Rupee (₹)';

  @override
  String get currencyJPY => 'Japanese Yen (¥)';

  @override
  String get currencyCAD => 'Canadian Dollar (C\$)';

  @override
  String get currencyAUD => 'Australian Dollar (A\$)';

  @override
  String get currencyCHF => 'Swiss Franc (CHF)';

  @override
  String get currencyCNY => 'Chinese Yuan (¥)';

  @override
  String get currencySGD => 'Singapore Dollar (S\$)';

  @override
  String get currencyHKD => 'Hong Kong Dollar (HK\$)';

  @override
  String get currencyBRL => 'Brazilian Real (R\$)';

  @override
  String get currencyMXN => 'Mexican Peso (MX\$)';

  @override
  String get currencyZAR => 'South African Rand (R)';

  @override
  String get readyToImport => 'Ready to Import';

  @override
  String get fireSetup => 'FIRE Setup';

  @override
  String get createGoal => 'Create Goal';

  @override
  String get share => 'Share';

  @override
  String get addManually => 'Add Manually';

  @override
  String get stepByStep => 'Step by step';

  @override
  String get importCsv => 'Import CSV';

  @override
  String get bulkUpload => 'Bulk upload';

  @override
  String get next => 'Next';

  @override
  String get sampleDataRemovalConfirmation =>
      'This will remove all sample investments and goals. You can always try sample data again later.';

  @override
  String errorOccurred(String error) {
    return 'Error: $error';
  }

  @override
  String get sampleDataMode => 'Sample Data Mode';

  @override
  String get exploringWithSampleInvestments =>
      'Exploring with sample investments';

  @override
  String get sampleDataKeepConfirmation =>
      'Sample investments will become your real data. You can edit or delete them anytime.';

  @override
  String get noResultsFound => 'No Results Found';

  @override
  String get tryDifferentSearchTerm => 'Try searching with a different term';

  @override
  String get noArchivedInvestments => 'No Archived Investments';

  @override
  String get archivedInvestmentsAppearHere =>
      'Investments you archive will appear here';

  @override
  String get noMatchingInvestments => 'No Matching Investments';

  @override
  String get tryDifferentFilter => 'Try a different filter';

  @override
  String get noInvestmentsFound => 'No investments found';

  @override
  String get netPosition => 'Net Position';

  @override
  String get bulkOpsNotAvailableForArchived =>
      'Bulk operations are not available for archived goals.\nUse swipe actions to delete or unarchive individual items.';

  @override
  String get newInvestmentName => 'New Investment Name';

  @override
  String get enterNameForMergedInvestment => 'Enter name for merged investment';

  @override
  String get investmentType => 'Investment Type';

  @override
  String get updateRequired => 'Update Required';

  @override
  String get updateAvailable => 'Update Available';

  @override
  String get newVersionAvailableMessage =>
      'A new version of InvTrack is available!';

  @override
  String get hiddenAmount => 'Hidden amount';

  @override
  String get portfolioHealth => 'Portfolio Health';

  @override
  String get portfolioHealthScore => 'Portfolio Health Score';

  @override
  String get portfolioHealthDetails => 'Portfolio Health Details';

  @override
  String get noPortfolioData => 'No data available';

  @override
  String get addInvestmentsToSeeHealth =>
      'Add investments to see your portfolio health score';

  @override
  String healthScoreTrendWeeks(int weeks) {
    return 'Score Trend (Last $weeks Weeks)';
  }

  @override
  String get healthScoreTrendNoData => 'Not enough data yet';

  @override
  String get healthScoreTrendCheckBack =>
      'Check back in a week to see your trend';

  @override
  String get hideDetails => 'Hide Details';

  @override
  String get showDetails => 'Show Details';

  @override
  String get historicalTrend => 'Historical Trend';

  @override
  String get componentBreakdown => 'Component Breakdown';

  @override
  String get topSuggestions => 'Top Suggestions';

  @override
  String get scoreCopiedToClipboard => 'Score copied to clipboard';

  @override
  String scoreImprovementPositive(int points) {
    return '+$points pts';
  }

  @override
  String scoreImprovementNegative(int points) {
    return '$points pts';
  }

  @override
  String get experimentalFeatures => 'Experimental Features';

  @override
  String get portfolioHealthScoreFeature => 'Portfolio Health Score';

  @override
  String get portfolioHealthScoreSubtitle =>
      'Unified health score (0-100) with trend chart';

  @override
  String get portfolioHealthScoreEnabled => 'Portfolio Health Score enabled';

  @override
  String get portfolioHealthScoreDisabled => 'Portfolio Health Score disabled';

  @override
  String get reportsTabFeature => 'Reports Tab';

  @override
  String get reportsTabSubtitle => 'Smart Insights and DIY Report Builder';

  @override
  String get reportsTabEnabled =>
      'Reports tab enabled - restart app to see changes';

  @override
  String get reportsTabDisabled =>
      'Reports tab disabled - restart app to see changes';

  @override
  String get incomeGuardianFeature => 'Income Guardian';

  @override
  String get incomeGuardianFeatureSubtitle =>
      'AI-powered income tracking with payment monitoring';

  @override
  String get incomeGuardianFeatureEnabled => 'Income Guardian enabled';

  @override
  String get incomeGuardianFeatureDisabled => 'Income Guardian disabled';

  @override
  String get dashboardIncomeGuardianBeta => 'BETA';

  @override
  String get dashboardIncomeGuardianSubtitle => 'AI-powered income tracking';

  @override
  String get dashboardOverdueBadge => 'OVERDUE';

  @override
  String get dashboardDueDate => 'Due Date';

  @override
  String get dashboardSource => 'Source';

  @override
  String get dashboardNoPendingPayments => 'No pending income payments';

  @override
  String get dashboardAllIncomeOnTrack => 'All income on track';

  @override
  String get healthScoreImproved => 'Score improved';

  @override
  String get healthScoreDeclined => 'Score declined';

  @override
  String healthScoreOutOf100(int score) {
    return 'Portfolio health score $score out of 100';
  }

  @override
  String shareScoreText(
    int score,
    String tier,
    int returns,
    int diversification,
    int liquidity,
    int goals,
    int actions,
  ) {
    return 'My InvTrack Portfolio Health Score: $score/100 ($tier)\n\n📊 Component Scores:\n- Returns: $returns/100\n- Diversification: $diversification/100\n- Liquidity: $liquidity/100\n- Goals: $goals/100\n- Actions: $actions/100\n\nTrack your investments with InvTrack!';
  }

  @override
  String get portfolioHealthSection => 'Portfolio Health Score';

  @override
  String get whatIsPortfolioHealthScore =>
      'What is the Portfolio Health Score?';

  @override
  String get whatIsPortfolioHealthScoreAnswer =>
      'Portfolio Health Score is like a Fitbit for your money - a single number (0-100) that tells you how healthy your investments are. It analyzes 5 key areas: Returns (30%), Diversification (25%), Liquidity (20%), Goal Alignment (15%), and Action Readiness (10%). Think of it as your portfolio\'s credit score!';

  @override
  String get howToEnablePortfolioHealth =>
      'How do I enable Portfolio Health Score?';

  @override
  String get howToEnablePortfolioHealthAnswer =>
      'Go to Settings → Debug Settings → Experimental Features and toggle \'Portfolio Health Score\' ON. The feature is currently in beta testing. You\'ll see your health score on the overview screen if you have investments.';

  @override
  String get whatDoScoreTiersMean => 'What do the score tiers mean?';

  @override
  String get whatDoScoreTiersMeanAnswer =>
      'Scores are categorized into 4 tiers:\n\n💚 Excellent (80-100): Your portfolio is thriving! Keep up the good work.\n\n💛 Good (60-79): Solid foundation with minor improvements possible.\n\n🧡 Fair (40-59): Attention needed. Review the suggestions.\n\n❤️ Poor (0-39): Urgent action required to improve portfolio health.';

  @override
  String get howToImproveMyScore => 'How can I improve my health score?';

  @override
  String get howToImproveMyScoreAnswer =>
      'Tap on your health score card to see detailed component scores and personalized suggestions. Each component (Returns, Diversification, Liquidity, Goals, Actions) shows specific recommendations to improve your portfolio health. Focus on the components with the lowest scores first.';

  @override
  String get isHealthScoreDataSaved => 'Is my health score data saved?';

  @override
  String get isHealthScoreDataSavedAnswer =>
      'Yes! Your health scores are automatically saved in your Firebase account and synced across devices. You can view your score trend over time in the details screen. Score history is included in data exports and deleted when you delete your account.';

  @override
  String get failedToLoadChartData => 'Failed to load chart data';

  @override
  String get pleaseTryAgain => 'Please try again';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get failedToGenerateReport => 'Failed to generate report';

  @override
  String get crashlyticsTestingTitle => 'Crashlytics Testing';

  @override
  String get enableCrashlyticsInDebugTitle =>
      'Enable Crashlytics in Debug Mode';

  @override
  String get crashlyticsEnabledSubtitle =>
      'Crashlytics is enabled - errors will be reported';

  @override
  String get crashlyticsDisabledSubtitle =>
      'Enable to test crash reporting in debug builds';

  @override
  String get crashlyticsEnabledSnack => 'Crashlytics enabled in debug mode';

  @override
  String get crashlyticsDisabledSnack => 'Crashlytics disabled in debug mode';

  @override
  String get testNonFatalTitle => 'Test Non-Fatal Error';

  @override
  String get testNonFatalSubtitle =>
      'Send a test error to Firebase Crashlytics';

  @override
  String get testFatalTitle => 'Test Fatal Crash';

  @override
  String get testFatalSubtitle => '⚠️ This will crash the app!';

  @override
  String get testNonFatalDialogTitle => 'Test Non-Fatal Error';

  @override
  String get testNonFatalDialogMessage =>
      'This will send a test non-fatal error to Firebase Crashlytics. The error will appear in your Firebase Console within a few minutes.\n\nContinue?';

  @override
  String get sendTestError => 'Send Test Error';

  @override
  String get testErrorSentSuccess =>
      'Test error sent to Crashlytics! Check Firebase Console in 5 minutes.';

  @override
  String get testFatalDialogTitle => 'Test Fatal Crash';

  @override
  String get testFatalDialogMessage =>
      '⚠️ WARNING: This will CRASH the app immediately!\n\nThe crash will be reported to Firebase Crashlytics and you will need to restart the app.\n\nOnly use this to verify Crashlytics is working correctly.\n\nContinue?';

  @override
  String get crashNow => 'Crash Now';

  @override
  String get crashlyticsDisabledWarning =>
      'Crashlytics is disabled in debug mode. Enable it in the toggle above to test crash reporting.';

  @override
  String get crashlyticsActiveInDebugTitle =>
      'Crashlytics Active in Debug Mode';

  @override
  String get crashlyticsInactiveInDebugTitle =>
      'Crashlytics Inactive in Debug Mode';

  @override
  String get crashlyticsActiveInDebugMessage =>
      'Crash reports are being sent to Firebase. You can test by clicking \"Test Fatal Crash\" below.';

  @override
  String get crashlyticsInactiveInDebugMessage =>
      'Crash reports are NOT being sent (debug mode default). Enable toggle above to test crash reporting.';

  @override
  String get crashlyticsWorksInReleaseNote =>
      '✓ Crashlytics works automatically in release builds';

  @override
  String get checkForUpdatesTitle => 'Check for Updates';

  @override
  String get checkingForUpdates => 'Checking...';

  @override
  String get appIsUpToDate => 'App is up to date';

  @override
  String get updatePromptMessage =>
      'A new version of InvTrack is available. Would you like to update now?';

  @override
  String get later => 'Later';

  @override
  String get update => 'Update';

  @override
  String get downloadingUpdateBackground =>
      'Downloading update in background...';

  @override
  String get criticalUpdateMessage =>
      'A critical update is available. Please update now.';

  @override
  String get inAppUpdateInstallTitle => 'Update Ready';

  @override
  String get inAppUpdateInstallMessage =>
      'Update has been downloaded. Restart the app to install?';

  @override
  String get inAppUpdateInstallButton => 'Restart';

  @override
  String get never => 'Never';

  @override
  String get reports => 'Reports';

  @override
  String get thisWeek => 'This Week';

  @override
  String get monthlyIncome => 'Monthly Income';

  @override
  String get thisMonth => 'This Month';

  @override
  String get fyReport => 'FY Report';

  @override
  String get performance => 'Performance';

  @override
  String get performanceReport => 'Performance Report';

  @override
  String get goalsReport => 'Goals Report';

  @override
  String get maturityCalendar => 'Maturity Calendar';

  @override
  String get topPerformers => 'Top Performers';

  @override
  String get maturity => 'Maturity';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get actionRequired => 'Action Required';

  @override
  String get quickReports => 'Quick Reports';

  @override
  String currentFY(String year1, String year2) {
    return 'FY $year1-$year2';
  }

  @override
  String fyLabel(String startYear, String endYear) {
    return 'FY $startYear-$endYear';
  }

  @override
  String paymentsReceived(int receivedCount, int totalCount) {
    return '$receivedCount of $totalCount payments received';
  }

  @override
  String get invested => 'Invested: ';

  @override
  String get viewDetails => 'View Details';

  @override
  String get noItemsToDisplay => 'No items to display';

  @override
  String get closed => 'CLOSED';

  @override
  String cashFlowEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String addedRelative(String relativeTime) {
    return 'Added $relativeTime';
  }

  @override
  String get allPaymentsFilter => 'All Payments';

  @override
  String get pendingFilter => 'Pending';

  @override
  String get overdueFilter => 'Overdue';

  @override
  String activeGoalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Active Goals',
      one: '1 Active Goal',
      zero: 'No Active Goals',
    );
    return '$_temp0';
  }

  @override
  String actionItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Items',
      one: '1 Item',
      zero: 'No Items',
    );
    return '$_temp0';
  }

  @override
  String healthScore(int score) {
    return 'Score: $score/100';
  }

  @override
  String get dailyCashflowTrend => 'Daily Cashflow Trend';

  @override
  String get historicalReports => 'Historical Reports';

  @override
  String get noHistoricalReportsYet => 'No historical reports yet';

  @override
  String get financialYearReports => 'Financial Year Reports';

  @override
  String get monthlyReports => 'Monthly Reports';

  @override
  String get currentYear => 'Current Year';

  @override
  String get currentMonth => 'Current Month';

  @override
  String get tapToView => 'Tap to view';

  @override
  String get january => 'January';

  @override
  String get february => 'February';

  @override
  String get march => 'March';

  @override
  String get april => 'April';

  @override
  String get may => 'May';

  @override
  String get june => 'June';

  @override
  String get july => 'July';

  @override
  String get august => 'August';

  @override
  String get september => 'September';

  @override
  String get october => 'October';

  @override
  String get november => 'November';

  @override
  String get december => 'December';

  @override
  String get exportReport => 'Export Report';

  @override
  String get exportAsCsv => 'Export as CSV';

  @override
  String get forSpreadsheetApps => 'For spreadsheet apps';

  @override
  String get exportAsPdf => 'Export as PDF';

  @override
  String get forSharingAndPrinting => 'For sharing & printing';

  @override
  String csvExportedSuccessfully(String size) {
    return 'CSV exported successfully ($size KB)';
  }

  @override
  String pdfExportedSuccessfully(String size) {
    return 'PDF exported successfully ($size KB)';
  }

  @override
  String failedToExportCsv(String error) {
    return 'Failed to export CSV: $error';
  }

  @override
  String failedToExportPdf(String error) {
    return 'Failed to export PDF: $error';
  }

  @override
  String get portfolioPerformance => 'Portfolio Performance';

  @override
  String get avgXirr => 'Avg XIRR';

  @override
  String get medianXirr => 'Median XIRR';

  @override
  String get profitable => 'Profitable';

  @override
  String get lossMaking => 'Loss Making';

  @override
  String get totalActions => 'Total Actions';

  @override
  String get urgent => 'Urgent';

  @override
  String get overdueActions => 'Overdue Actions';

  @override
  String get criticalActions => '⚠️ Critical Actions';

  @override
  String get highPriority => '🔴 High Priority';

  @override
  String get goalsOverview => 'Goals Overview';

  @override
  String get totalGoals => 'Total Goals';

  @override
  String get avgProgress => 'Avg Progress';

  @override
  String get totalInvested => 'Total Invested';

  @override
  String get totalReturns => 'Total Returns';

  @override
  String get weeklySummaryTitle => 'Weekly Summary';

  @override
  String get monthlyIncomeReportTitle => 'Monthly Income Report';

  @override
  String get fyReportTitle => 'Financial Year Report';

  @override
  String get performanceReportTitle => 'Performance Report';

  @override
  String get goalProgressReportTitle => 'Goal Progress Report';

  @override
  String get goalProgressTitle => 'Goal Progress Report';

  @override
  String get targetLabel => 'Target';

  @override
  String get maturityCalendarTitle => 'Maturity Calendar';

  @override
  String get actionRequiredTitle => 'Action Required';

  @override
  String get portfolioHealthTitle => 'Portfolio Health';

  @override
  String get totalIncome => 'Total Income';

  @override
  String get totalFees => 'Total Fees';

  @override
  String get netCashflow => 'Net Cashflow';

  @override
  String get totalReturned => 'Total Returned';

  @override
  String get topPerformer => 'Top Performer';

  @override
  String get newInvestments => 'New Investments';

  @override
  String get upcomingMaturities => 'Upcoming Maturities';

  @override
  String get incomeBreakdown => 'Income Breakdown';

  @override
  String get topIncomeGenerators => 'Top Income Generators';

  @override
  String get allTransactions => 'All Transactions';

  @override
  String get xirrLabel => 'XIRR';

  @override
  String get monthlyBreakdown => 'Monthly Breakdown';

  @override
  String get capitalGainsSummary => 'Capital Gains Summary';

  @override
  String get capitalGains => 'Capital Gains';

  @override
  String get investedLabel => 'Invested';

  @override
  String get returnedLabel => 'Returned';

  @override
  String get shortTermGains => 'Short-term Gains';

  @override
  String get longTermGains => 'Long-term Gains';

  @override
  String get topPerformersByReturns => 'Top Performers (by Returns)';

  @override
  String get topPerformersByXirr => 'Top Performers (by XIRR)';

  @override
  String get topPerformersSection => 'Top Performers';

  @override
  String get bottomPerformers => 'Bottom Performers';

  @override
  String get recentMilestones => 'Recent Milestones';

  @override
  String get onTrack => 'On Track';

  @override
  String get atRisk => 'At Risk';

  @override
  String get achieved => 'Achieved';

  @override
  String get goalsOnTrack => 'Goals On Track';

  @override
  String get goalsAtRisk => 'Goals At Risk';

  @override
  String get maturityOverview => 'Maturity Overview';

  @override
  String get totalWithMaturity => 'Total w/ Maturity';

  @override
  String get next30Days => 'Next 30 Days';

  @override
  String get next90Days => 'Next 90 Days';

  @override
  String get upcomingMaturitiesSection => 'Upcoming Maturities';

  @override
  String get maturesSoon => 'Matures Soon';

  @override
  String get next90DaysTotal => 'Next 90 Days Total';

  @override
  String get maturesLabel => 'Matures';

  @override
  String get allClear => 'All Clear!';

  @override
  String get noActionsRequired => 'No actions required at this time.';

  @override
  String get urgentActions => 'Urgent';

  @override
  String get overdueItems => 'Overdue';

  @override
  String get maturedInvestments => 'Matured Investments';

  @override
  String get missedDividends => 'Missed Dividends';

  @override
  String get missingData => 'Missing Data';

  @override
  String get overallHealthScore => 'Overall Health Score';

  @override
  String get healthMetrics => 'Health Metrics';

  @override
  String get diversification => 'Diversification';

  @override
  String get performanceLabel => 'Performance';

  @override
  String get activity => 'Activity';

  @override
  String get typesLabel => 'Types';

  @override
  String get investmentsLabel => 'investments';

  @override
  String get returnsQuality => 'Returns Quality';

  @override
  String get dataCompleteness => 'Data Completeness';

  @override
  String get riskLevel => 'Risk Level';

  @override
  String get recommendationsSection => 'Recommendations';

  @override
  String get byType => 'By Type';

  @override
  String get byStatus => 'By Status';

  @override
  String get summary => 'Summary';

  @override
  String get xirrTooltip =>
      'Extended Internal Rate of Return - Industry standard for calculating returns with multiple transactions at different times. Accounts for when you invested and withdrew money.';

  @override
  String get capitalGainsTooltip =>
      'Profit from selling investments. Short-term (<1 year) gains are taxed higher than long-term (>1 year) gains in India.';

  @override
  String get netCashflowTooltip =>
      'Total money in (dividends, interest) minus money out (investments, withdrawals) for the period. Positive = earning, Negative = investing.';

  @override
  String get diversificationTooltip =>
      'How spread out your investments are across types and platforms. Higher diversification = lower risk.';

  @override
  String get liquidityTooltip =>
      'Percentage of your portfolio maturing in next 90 days. Ideal: 10-30%. Too high = reinvestment work, Too low = illiquid.';

  @override
  String get goalAlignmentTooltip =>
      'Percentage of your financial goals that are on-track based on current progress. Higher = better goal achievement.';

  @override
  String get actionReadinessTooltip =>
      'Measures overdue renewals and stale investments. Lower score means you have pending actions to take.';

  @override
  String get maturingNext30Days => '⏰ Maturing in Next 30 Days';

  @override
  String get maturing31to90Days => '📅 Maturing in 31-90 Days';

  @override
  String get maturingBeyond90Days => '🗓️ Maturing Beyond 90 Days';

  @override
  String daysRemaining(int days) {
    return '$days days remaining';
  }

  @override
  String get bottomPerformersSection => '📉 Bottom Performers';

  @override
  String get recentMilestonesSection => '🎯 Recent Milestones';

  @override
  String get achievedGoalsSection => '🎉 Achieved Goals';

  @override
  String get highPrioritySection => '🔴 High Priority';

  @override
  String get mediumPrioritySection => '🟡 Medium Priority';

  @override
  String get lowPrioritySection => '🔵 Low Priority';

  @override
  String get archiveGoal => 'Archive Goal';

  @override
  String get unarchiveGoal => 'Unarchive Goal';

  @override
  String get googleAccountExists => 'Google Account Already Exists';

  @override
  String get accountAlreadyRegistered =>
      'This Google account is already registered.';

  @override
  String get guestDataBackupMessage =>
      'Your guest data will be backed up as a ZIP file. After signing in, you can import it to merge with existing data.';

  @override
  String get backupAndSignIn => 'Backup & Sign In';

  @override
  String get backupCreated => 'Backup Created';

  @override
  String get guestDataBackedUp => 'Your guest data has been backed up.';

  @override
  String backupLocation(String path) {
    return 'Location: $path';
  }

  @override
  String get importNowQuestion => 'Would you like to import it now?';

  @override
  String get importNow => 'Import Now';

  @override
  String backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get reportPdfDailyCashflows => 'Daily Cashflows';

  @override
  String get reportPdfTableHeaderDate => 'Date';

  @override
  String get reportPdfTableHeaderInflow => 'Inflow';

  @override
  String get reportPdfTableHeaderOutflow => 'Outflow';

  @override
  String get reportPdfTableHeaderNet => 'Net';

  @override
  String maturesOnDate(String date) {
    return '$date';
  }

  @override
  String dueOnDate(String date) {
    return 'Due: $date';
  }

  @override
  String get overdue => 'OVERDUE';

  @override
  String daysShort(int days) {
    return '${days}d';
  }

  @override
  String get reportPdfTotalInvested => 'Total Invested';

  @override
  String get reportPdfTotalReturned => 'Total Returned';

  @override
  String get reportPdfNetPosition => 'Net Position';

  @override
  String get reportPdfNewInvestments => 'New Investments';

  @override
  String get reportPdfTotalIncome => 'Total Income';

  @override
  String get reportPdfTransactions => 'Transactions';

  @override
  String get reportPdfXirr => 'XIRR';

  @override
  String get reportPdfHealthScore => 'Health Score';

  @override
  String get reportPdfStatus => 'Status';

  @override
  String get reportPdfIncomeByType => 'Income by Type';

  @override
  String get reportPdfMonthlyBreakdown => 'Monthly Breakdown';

  @override
  String get reportPdfTopPerformers => 'Top Performers';

  @override
  String get reportPdfBottomPerformers => 'Bottom Performers';

  @override
  String get reportPdfOnTrackGoals => 'On-Track Goals';

  @override
  String get reportPdfAtRiskGoals => 'At-Risk Goals';

  @override
  String get reportPdfUpcomingMaturities => 'Upcoming Maturities';

  @override
  String get reportPdfIdleInvestments => 'Idle Investments';

  @override
  String get reportPdfDiversification => 'Diversification';

  @override
  String get noDataForReport => 'No data available for this report';

  @override
  String get startTrackingToSeeReports =>
      'Start tracking investments to see reports';

  @override
  String get addYourFirstInvestment => 'Add Your First Investment';

  @override
  String get smartInsights => 'Smart Insights';

  @override
  String get reportBuilder => 'Report Builder';

  @override
  String get createCustomReport => 'Create Custom Report';

  @override
  String get createReport => 'Create Report';

  @override
  String get viewPastReports => 'View Past Reports';

  @override
  String get needsAttention => 'Needs Attention';

  @override
  String investmentsDown(int count) {
    return '$count investments down >10%';
  }

  @override
  String upcomingMaturityWarning(String amount, int days) {
    return '₹$amount maturing in $days days';
  }

  @override
  String goalsBehindSchedule(int count) {
    return '$count goals behind schedule';
  }

  @override
  String get netInvestedThisWeek => 'Net invested this week';

  @override
  String get netInvestedThisMonth => 'Net invested this month';

  @override
  String get returnsThisWeek => 'Returns this week';

  @override
  String get returnsThisMonth => 'Returns this month';

  @override
  String get incomeReceived => 'Income received';

  @override
  String sourcesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sources',
      one: '1 source',
    );
    return '$_temp0';
  }

  @override
  String get ytdPerformance => 'YTD Performance';

  @override
  String portfolioUpVsGoal(String actual, String target) {
    return 'Portfolio up $actual% vs goal of $target%';
  }

  @override
  String get recentlyViewed => 'Recently Viewed';

  @override
  String get reportTemplates => 'Templates';

  @override
  String get investmentPerformance => 'Investment Performance';

  @override
  String get taxPlanning => 'Tax Planning';

  @override
  String get cashFlowAnalysis => 'Cash Flow Analysis';

  @override
  String get whatToAnalyze => 'What do you want to analyze?';

  @override
  String get timePeriod => 'Time Period';

  @override
  String get filterBy => 'Filter By (Optional)';

  @override
  String get generateReport => 'Generate Report';

  @override
  String get customDateRange => 'Custom';

  @override
  String get category => 'Category';

  @override
  String get minAmount => 'Min Amount';

  @override
  String get allTypes => 'All';

  @override
  String get calculateYourFireNumber => 'Calculate Your FIRE Number';

  @override
  String get setupFinancialIndependenceGoals =>
      'Set up your financial independence goals';

  @override
  String get moicLabel => 'MOIC';

  @override
  String overDuration(String duration) {
    return 'over $duration';
  }

  @override
  String get cashFlowsLabel => 'Cash Flows';

  @override
  String get fireProgressTitle => 'FIRE Progress';

  @override
  String get selectReportType => 'Select Report Type';

  @override
  String get selectDateRange => 'Select Date Range';

  @override
  String get selectFilters => 'Select Filters';

  @override
  String get chooseReportType =>
      'Choose the type of report you want to generate';

  @override
  String get weeklySummaryDesc =>
      'View activity and cashflows for the selected week';

  @override
  String get monthlyIncomeDesc => 'Track income from investments for the month';

  @override
  String get fyReportDesc => 'Comprehensive financial year analysis';

  @override
  String get performanceReportDesc =>
      'Analyze top and bottom performing investments';

  @override
  String get goalsReportDesc => 'Track progress towards your financial goals';

  @override
  String get maturityCalendarDesc => 'View upcoming investment maturities';

  @override
  String get selectTimeframe => 'Select the time period for your report';

  @override
  String get thisQuarter => 'This Quarter';

  @override
  String get thisYear => 'This Year';

  @override
  String get lastThreeMonths => 'Last 3 Months';

  @override
  String get lastSixMonths => 'Last 6 Months';

  @override
  String get lastYear => 'Last Year';

  @override
  String get allTime => 'All Time';

  @override
  String get optionalFilters =>
      'Apply optional filters to narrow down your report';

  @override
  String get filterByInvestment => 'Filter by Investment';

  @override
  String get filterByGoal => 'Filter by Goal';

  @override
  String get allInvestments => 'All Investments';

  @override
  String get allGoals => 'All Goals';

  @override
  String get errorLoadingInvestments => 'Error loading investments';

  @override
  String get errorLoadingGoals => 'Error loading goals';

  @override
  String get noFiltersNeeded => 'No filters available for this report type';

  @override
  String get noFiltersNeededDesc =>
      'This report does not require any additional filters. Proceed to generate the report.';

  @override
  String get pleaseSelectReportType =>
      'Please select a report type to continue';

  @override
  String get continueStep => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get upcomingMaturityInsight => 'Upcoming Maturity';

  @override
  String upcomingMaturityDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count investments',
      one: '1 investment',
    );
    return '$_temp0 maturing in next 30 days';
  }

  @override
  String get monthlyIncomeInsight => 'Monthly Income';

  @override
  String monthlyIncomeDescription(String amount) {
    return '$amount in passive income this month';
  }

  @override
  String get goalProgressInsight => 'Goal Progress';

  @override
  String goalProgressDescription(String goalName, int percent) {
    return '$goalName is $percent% complete';
  }

  @override
  String get topPerformerInsight => 'Top Performer';

  @override
  String topPerformerDescription(String investmentName, String returnValue) {
    return '$investmentName returned $returnValue%';
  }

  @override
  String get idleInvestmentReviewTitle => '💤 Investment Review Needed';

  @override
  String idleInvestmentReviewBody(
    String investmentName,
    int daysSinceActivity,
  ) {
    return '$investmentName has had no activity for $daysSinceActivity days. Review this investment?';
  }

  @override
  String idleInvestmentNoActivityBody(String investmentName) {
    return '$investmentName has no recorded activity. Consider adding cash flows.';
  }

  @override
  String get decliningInValue => 'Declining in value';

  @override
  String get dataManagementExportSection => 'Export';

  @override
  String get dataManagementImportSection => 'Import';

  @override
  String get dataManagementDangerZoneSection => 'Danger Zone';

  @override
  String get exportAsCsvSubtitle => 'Spreadsheet format';

  @override
  String get exportAsZip => 'Export as ZIP';

  @override
  String get exportAsZipSubtitle => 'Full backup with documents';

  @override
  String get importFromCsv => 'Import from CSV';

  @override
  String get importFromCsvSubtitle => 'Add investments from file';

  @override
  String get importFromZip => 'Import from ZIP';

  @override
  String get importFromZipSubtitle => 'Restore from backup';

  @override
  String get deleteAccountSubtitle => 'Permanently delete all data';

  @override
  String get deletingStatus => 'Deleting...';

  @override
  String get dataManagementWarning =>
      '⚠️ Warning: Deleting your account is permanent and cannot be undone. All your data will be lost.';

  @override
  String get importDataHandlingTitle => 'How should we handle existing data?';

  @override
  String get importMergeOption => 'Merge';

  @override
  String get importMergeSubtitle => 'Add new data, skip duplicates';

  @override
  String get importReplaceOption => 'Replace';

  @override
  String get importReplaceSubtitle => 'Delete existing data first';

  @override
  String get exportSuccessMessage => 'Data exported successfully!';

  @override
  String get exportFailureMessage => 'Failed to export data';

  @override
  String get importSuccessMessage => 'Data imported successfully!';

  @override
  String get importFailureMessage => 'Failed to import data';

  @override
  String get importCancelledMessage => 'Import cancelled';

  @override
  String get incomeTrendReport => 'Income Trend Report';

  @override
  String get totalIncomeLast12Months => 'Total Income (Last 12 Months)';

  @override
  String get averageMonthly => 'Average Monthly';

  @override
  String get growthMetrics => 'Growth Metrics';

  @override
  String get monthOverMonth => 'Month-over-Month';

  @override
  String get quarterOverQuarter => 'Quarter-over-Quarter';

  @override
  String get monthlyIncomeTrend => 'Monthly Income Trend';

  @override
  String get platformReliability => 'Platform Reliability';

  @override
  String get incomeDiversification => 'Income Diversification';

  @override
  String get keyInsights => 'Key Insights';

  @override
  String get incomeCalendar => 'Income Calendar';

  @override
  String get trendReportLoadFailed => 'Failed to load income trend report';

  @override
  String get trendReportRetry => 'Retry';

  @override
  String get diversificationExcellent => 'Excellent diversification';

  @override
  String get diversificationModerate => 'Moderate concentration';

  @override
  String get diversificationHigh => 'High concentration';

  @override
  String get diversificationRisky => 'Very high concentration - Risky';

  @override
  String get expectedIncomeOverduePayments => 'Overdue Payments';

  @override
  String get expectedIncomeUpcomingPayments => 'Upcoming Payments';

  @override
  String get expectedIncomePaymentHistory => 'Payment History';

  @override
  String get expectedIncomeNoPayments => 'No Expected Payments';

  @override
  String get expectedIncomeNoPaymentsSubtitle =>
      'This investment has no predicted income payments';

  @override
  String get expectedIncomeLoadFailed => 'Failed to load expected payments';

  @override
  String get expectedIncomePaymentReliability => 'Payment Reliability';

  @override
  String expectedIncomeReceived(String amount) {
    return 'Received: $amount';
  }

  @override
  String get growthTrendStrong => 'Strong Growth';

  @override
  String get growthTrendPositive => 'Positive Growth';

  @override
  String get growthTrendStable => 'Stable';

  @override
  String get growthTrendDeclining => 'Declining';

  @override
  String get platformReliabilityExcellent => 'Excellent';

  @override
  String get platformReliabilityGood => 'Good';

  @override
  String get platformReliabilityFair => 'Fair';

  @override
  String get platformReliabilityPoor => 'Poor';

  @override
  String get semanticSelectMaturityDate => 'Select Maturity Date';

  @override
  String get semanticSelectStartDate => 'Select Start Date';

  @override
  String get notSet => 'Not set';

  @override
  String get tooltipUseBiometric => 'Use biometric authentication';

  @override
  String get tooltipClearPasscode => 'Clear passcode';

  @override
  String get tooltipDeleteDigit => 'Delete last digit';
}
