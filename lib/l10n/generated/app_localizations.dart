import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'InvTrack'**
  String get appTitle;

  /// Overview tab label
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// Investments tab label
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get investments;

  /// Goals tab label
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// Settings tab label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Currency label
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// Select currency dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get selectCurrency;

  /// Locale settings label
  ///
  /// In en, this message translates to:
  /// **'Language & Region'**
  String get locale;

  /// Date format settings label
  ///
  /// In en, this message translates to:
  /// **'Date Format'**
  String get dateFormat;

  /// Today label for relative dates
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get today;

  /// Yesterday label for relative dates
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get yesterday;

  /// Shows days in the past
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(int days);

  /// Weeks ago label for relative dates
  ///
  /// In en, this message translates to:
  /// **'{count} weeks ago'**
  String weeksAgo(int count);

  /// Months ago label for relative dates
  ///
  /// In en, this message translates to:
  /// **'{count} months ago'**
  String monthsAgo(int count);

  /// Years ago label for relative dates
  ///
  /// In en, this message translates to:
  /// **'{count} years ago'**
  String yearsAgo(int count);

  /// Semantic label for investment notes icon and screen reader announcement
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// Sign in button label
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Sign out button label
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Add button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Done button label
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Skip button label
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Appearance settings screen title
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Theme section title
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Theme section description
  ///
  /// In en, this message translates to:
  /// **'Choose how InvTrack looks'**
  String get themeDescription;

  /// System theme option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// System theme option subtitle
  ///
  /// In en, this message translates to:
  /// **'Match device settings'**
  String get themeSystemSubtitle;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Light theme option subtitle
  ///
  /// In en, this message translates to:
  /// **'Always use light theme'**
  String get themeLightSubtitle;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Dark theme option subtitle
  ///
  /// In en, this message translates to:
  /// **'Always use dark theme'**
  String get themeDarkSubtitle;

  /// Preview label for theme preview
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// Primary color label
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primary;

  /// Success color label
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Error color label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorColor;

  /// General settings section title
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// Security settings section title
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// App lock settings title
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get appLock;

  /// PIN enabled status
  ///
  /// In en, this message translates to:
  /// **'PIN enabled'**
  String get pinEnabled;

  /// Biometrics enabled status
  ///
  /// In en, this message translates to:
  /// **'Biometrics on'**
  String get biometricsOn;

  /// App lock subtitle when disabled
  ///
  /// In en, this message translates to:
  /// **'Protect your data'**
  String get protectYourData;

  /// Notifications settings title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Notifications subtitle
  ///
  /// In en, this message translates to:
  /// **'Reminders & summaries'**
  String get remindersAndSummaries;

  /// Data and account settings title
  ///
  /// In en, this message translates to:
  /// **'Data & Account'**
  String get dataAndAccount;

  /// Data and account subtitle
  ///
  /// In en, this message translates to:
  /// **'Import, export, backup & delete'**
  String get importExportBackupDelete;

  /// About section title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// About InvTrack title
  ///
  /// In en, this message translates to:
  /// **'About InvTrack'**
  String get aboutInvTrack;

  /// About InvTrack subtitle
  ///
  /// In en, this message translates to:
  /// **'Version, legal & support'**
  String get versionLegalSupport;

  /// Sign out confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmTitle;

  /// Sign out confirmation dialog message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmMessage;

  /// Notifications screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsSectionTitle;

  /// Summaries section title
  ///
  /// In en, this message translates to:
  /// **'Summaries'**
  String get summaries;

  /// Summaries section footer
  ///
  /// In en, this message translates to:
  /// **'Periodic updates about your portfolio performance'**
  String get periodicUpdatesAboutPortfolio;

  /// Weekly summary report title
  ///
  /// In en, this message translates to:
  /// **'Weekly Summary'**
  String get weeklySummary;

  /// Weekly summary subtitle
  ///
  /// In en, this message translates to:
  /// **'Get a summary every Sunday'**
  String get getSummaryEverySunday;

  /// Monthly summary toggle title
  ///
  /// In en, this message translates to:
  /// **'Monthly Summary'**
  String get monthlySummary;

  /// Monthly summary subtitle
  ///
  /// In en, this message translates to:
  /// **'End of month income recap'**
  String get endOfMonthIncomeRecap;

  /// Reminders section title
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// Reminders section footer
  ///
  /// In en, this message translates to:
  /// **'Stay on top of upcoming events'**
  String get stayOnTopOfUpcomingEvents;

  /// Income reminders toggle title
  ///
  /// In en, this message translates to:
  /// **'Income Reminders'**
  String get incomeReminders;

  /// Income reminders subtitle
  ///
  /// In en, this message translates to:
  /// **'When income is expected'**
  String get whenIncomeIsExpected;

  /// Maturity reminders toggle title
  ///
  /// In en, this message translates to:
  /// **'Maturity Reminders'**
  String get maturityReminders;

  /// Maturity reminders subtitle
  ///
  /// In en, this message translates to:
  /// **'Before investments mature'**
  String get beforeInvestmentsMature;

  /// Goal milestones toggle title
  ///
  /// In en, this message translates to:
  /// **'Goal Milestones'**
  String get goalMilestones;

  /// Goal milestones subtitle
  ///
  /// In en, this message translates to:
  /// **'Celebrate at 25%, 50%, 75%, 100%'**
  String get celebrateAtMilestones;

  /// Debug section title
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// Test notification button title
  ///
  /// In en, this message translates to:
  /// **'Test Notification'**
  String get testNotification;

  /// Test notification subtitle
  ///
  /// In en, this message translates to:
  /// **'Send an immediate test'**
  String get sendImmediateTest;

  /// Test notification success message
  ///
  /// In en, this message translates to:
  /// **'Test notification sent!'**
  String get testNotificationSent;

  /// Permission denied message
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get permissionDenied;

  /// Scheduled test button title
  ///
  /// In en, this message translates to:
  /// **'Scheduled Test'**
  String get scheduledTest;

  /// Scheduled test subtitle
  ///
  /// In en, this message translates to:
  /// **'Notify in 5 seconds'**
  String get notifyInFiveSeconds;

  /// Scheduled test success message
  ///
  /// In en, this message translates to:
  /// **'Scheduled for 5 seconds'**
  String get scheduledForFiveSeconds;

  /// Security screen title
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTitle;

  /// App lock section title
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get appLockSection;

  /// App lock footer when PIN is set
  ///
  /// In en, this message translates to:
  /// **'Your app is protected with a PIN'**
  String get yourAppIsProtectedWithPin;

  /// App lock footer when PIN is not set
  ///
  /// In en, this message translates to:
  /// **'Add a PIN to protect your data'**
  String get addPinToProtectData;

  /// Enable app lock toggle title
  ///
  /// In en, this message translates to:
  /// **'Enable App Lock'**
  String get enableAppLock;

  /// App lock subtitle when PIN is set
  ///
  /// In en, this message translates to:
  /// **'PIN required to open app'**
  String get pinRequiredToOpenApp;

  /// App lock subtitle when PIN is not set
  ///
  /// In en, this message translates to:
  /// **'Protect with a 4-digit PIN'**
  String get protectWithFourDigitPin;

  /// Quick unlock section title
  ///
  /// In en, this message translates to:
  /// **'Quick Unlock'**
  String get quickUnlock;

  /// Quick unlock section footer
  ///
  /// In en, this message translates to:
  /// **'Use biometrics for faster access'**
  String get useBiometricsForFasterAccess;

  /// Biometric toggle title
  ///
  /// In en, this message translates to:
  /// **'Face ID / Touch ID'**
  String get faceIdTouchId;

  /// Biometric toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get unlockWithBiometrics;

  /// Biometric enrollment dialog title
  ///
  /// In en, this message translates to:
  /// **'Enable Biometric Unlock?'**
  String get enableBiometricUnlock;

  /// Biometric enrollment dialog message
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face recognition for faster access to your app.'**
  String get useFingerprintOrFaceForFasterAccess;

  /// Biometric enrollment dialog negative button
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// Biometric enrollment dialog positive button
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// Snackbar message when biometric is enabled
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock enabled'**
  String get biometricUnlockEnabled;

  /// Manage PIN section title
  ///
  /// In en, this message translates to:
  /// **'Manage PIN'**
  String get managePin;

  /// Change PIN button title
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// Change PIN subtitle
  ///
  /// In en, this message translates to:
  /// **'Update your security code'**
  String get updateYourSecurityCode;

  /// Security info message
  ///
  /// In en, this message translates to:
  /// **'Your investment data is stored locally on this device and is never uploaded to external servers.'**
  String get dataStoredLocallyMessage;

  /// Help & FAQ screen title
  ///
  /// In en, this message translates to:
  /// **'Help & FAQ'**
  String get helpFaqTitle;

  /// Getting started section title
  ///
  /// In en, this message translates to:
  /// **'Getting Started'**
  String get gettingStarted;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How do I add my first investment?'**
  String get howToAddFirstInvestment;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Tap the \"+\" button on the Investments tab. Enter your investment details including name, amount, date, and category. You can also add transactions later to track your investment growth.'**
  String get howToAddFirstInvestmentAnswer;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'What investment types are supported?'**
  String get whatInvestmentTypesSupported;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'InvTrack supports Stocks, Mutual Funds, Fixed Deposits, Gold, Real Estate, Crypto, and more. You can categorize any investment type.'**
  String get whatInvestmentTypesSupportedAnswer;

  /// Tracking Returns section title
  ///
  /// In en, this message translates to:
  /// **'Tracking Returns'**
  String get trackingReturns;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How are returns calculated?'**
  String get howAreReturnsCalculated;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'InvTrack uses XIRR (Extended Internal Rate of Return) to calculate accurate returns considering all your transactions and their timing. This gives you a true picture of your investment performance.'**
  String get howAreReturnsCalculatedAnswer;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'What is XIRR?'**
  String get whatIsXirr;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'XIRR is the industry-standard method for calculating returns on investments with multiple cash flows at different times. It accounts for when you invested and when you withdrew money.'**
  String get whatIsXirrAnswer;

  /// Goals section title
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goalsSection;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How do I set a financial goal?'**
  String get howToSetFinancialGoal;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Go to the Goals tab and tap \"+\". Enter your goal name, target amount, and deadline. InvTrack will track your progress and show how much you need to save.'**
  String get howToSetFinancialGoalAnswer;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'Can I link investments to goals?'**
  String get canLinkInvestmentsToGoals;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Yes! When creating or editing a goal, you can allocate specific investments toward that goal. This helps you track progress toward multiple goals simultaneously.'**
  String get canLinkInvestmentsToGoalsAnswer;

  /// Privacy & Security section title
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacyAndSecurity;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'Is my data secure?'**
  String get isMyDataSecure;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Yes! All your data is stored securely in Firebase with encryption. You can also enable app lock with PIN or biometrics for extra security.'**
  String get isMyDataSecureAnswer;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'What is Privacy Mode?'**
  String get whatIsPrivacyMode;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Privacy Mode hides all financial amounts in the app, showing \"•••••\" instead. Perfect for when you want to check your portfolio in public. Toggle it from Settings → Appearance.'**
  String get whatIsPrivacyModeAnswer;

  /// Data Management section title
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagementSection;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'Can I export my data?'**
  String get canExportMyData;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Yes! Go to Settings → Data & Account → Export Data. You can download all your investment data as a ZIP file containing CSV files.'**
  String get canExportMyDataAnswer;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How do I backup my data?'**
  String get howToBackupData;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Your data is automatically backed up to Firebase when you\'\'re signed in. You can also export a local backup anytime from Settings → Data & Account.'**
  String get howToBackupDataAnswer;

  /// Multi-Currency Support section title
  ///
  /// In en, this message translates to:
  /// **'Multi-Currency Support'**
  String get multiCurrencySupport;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'Can I change my currency?'**
  String get canChangeMyCurrency;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Yes! Go to Settings → Currency and select from 40+ supported currencies. The app will format all amounts according to your selected currency and locale.'**
  String get canChangeMyCurrencyAnswer;

  /// FAQ question
  ///
  /// In en, this message translates to:
  /// **'How does currency formatting work?'**
  String get howDoesCurrencyFormattingWork;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'InvTrack automatically formats numbers based on your currency:\n• Indian Rupee (₹): Shows 1L, 10L, 1Cr\n• USD/EUR/GBP: Shows 100K, 1M, 10M\n• Other currencies use appropriate locale formatting'**
  String get howDoesCurrencyFormattingWorkAnswer;

  /// Help contact message
  ///
  /// In en, this message translates to:
  /// **'Need more help? Contact support@invtracker.com'**
  String get needMoreHelpContact;

  /// Income Guardian section title in Help & FAQ
  ///
  /// In en, this message translates to:
  /// **'Income Guardian'**
  String get incomeGuardianSection;

  /// FAQ question about Income Guardian feature
  ///
  /// In en, this message translates to:
  /// **'What is Income Guardian?'**
  String get whatIsIncomeGuardian;

  /// FAQ answer about Income Guardian feature
  ///
  /// In en, this message translates to:
  /// **'Income Guardian is an AI-powered income monitoring system that predicts when you should receive payments from your investments, tracks platform reliability, and alerts you to missed or delayed income. It transforms InvTrack from passive tracking to active wealth protection.'**
  String get whatIsIncomeGuardianAnswer;

  /// FAQ question about income projection mechanism
  ///
  /// In en, this message translates to:
  /// **'How does income projection work?'**
  String get howDoesIncomeProjectionWork;

  /// FAQ answer about income projection mechanism
  ///
  /// In en, this message translates to:
  /// **'Income Guardian uses Weighted Moving Average (WMA) machine learning to predict your next payment amount based on your last 6 payments. It learns platform-specific payment delays (e.g., LenDenClub pays 2 days late) and adjusts expectations automatically. For stable payments, it applies ±8% tolerance; for volatile payments, tolerance expands to match historical variance.'**
  String get howDoesIncomeProjectionWorkAnswer;

  /// FAQ question about income trend analysis
  ///
  /// In en, this message translates to:
  /// **'What is Income Trend Analysis?'**
  String get whatIsIncomeTrendAnalysis;

  /// FAQ answer about income trend analysis
  ///
  /// In en, this message translates to:
  /// **'Income Trend Analysis provides month-over-month (MoM) and quarter-over-quarter (QoQ) growth metrics, platform reliability scores, and auto-generated insights. It helps you track income growth, identify unreliable platforms, and optimize your portfolio for consistent cash flow.'**
  String get whatIsIncomeTrendAnalysisAnswer;

  /// FAQ question about HHI score
  ///
  /// In en, this message translates to:
  /// **'What is the HHI (Herfindahl-Hirschman Index) score?'**
  String get whatIsHHIScore;

  /// FAQ answer about HHI score
  ///
  /// In en, this message translates to:
  /// **'HHI measures income concentration risk. A score of 1.0 means all income comes from one platform (maximum risk). A score of 0.33 means income is evenly distributed across 3+ platforms (well-diversified). Lower scores indicate better diversification and reduced risk of income loss from a single platform failure.'**
  String get whatIsHHIScoreAnswer;

  /// FAQ question about platform reliability
  ///
  /// In en, this message translates to:
  /// **'What is Platform Reliability Score?'**
  String get whatIsPlatformReliability;

  /// FAQ answer about platform reliability score
  ///
  /// In en, this message translates to:
  /// **'Platform Reliability Score (0-100%) measures how consistently a platform pays on time and with the expected amount. Scores ≥80% are excellent (green), 60-80% are acceptable (yellow), and <60% indicate frequent delays or payment issues (red). This helps you identify which platforms are most reliable for your income.'**
  String get whatIsPlatformReliabilityAnswer;

  /// Income Guardian settings screen title
  ///
  /// In en, this message translates to:
  /// **'Income Guardian'**
  String get incomeGuardianSettings;

  /// Income Guardian general settings section title
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get incomeGuardianGeneral;

  /// Income Guardian enable toggle footer text
  ///
  /// In en, this message translates to:
  /// **'Enable automated income tracking and payment notifications'**
  String get enableIncomeGuardian;

  /// Income Guardian enabled subtitle
  ///
  /// In en, this message translates to:
  /// **'Monitoring your expected payments'**
  String get incomeGuardianEnabled;

  /// Income Guardian disabled subtitle
  ///
  /// In en, this message translates to:
  /// **'Tap to enable automated tracking'**
  String get incomeGuardianDisabled;

  /// Notification timing settings section title
  ///
  /// In en, this message translates to:
  /// **'Notification Timing'**
  String get notificationTiming;

  /// Notification timing settings section footer
  ///
  /// In en, this message translates to:
  /// **'Configure when you want to be notified about expected payments'**
  String get notificationTimingFooter;

  /// Upcoming payment alert setting title
  ///
  /// In en, this message translates to:
  /// **'Upcoming Payment Alert'**
  String get upcomingPaymentAlert;

  /// Upcoming payment alert setting subtitle
  ///
  /// In en, this message translates to:
  /// **'{days} day{plural} before expected date'**
  String upcomingPaymentAlertSubtitle(int days, String plural);

  /// Overdue payment alert setting title
  ///
  /// In en, this message translates to:
  /// **'Overdue Payment Alert'**
  String get overduePaymentAlert;

  /// Overdue payment alert setting subtitle
  ///
  /// In en, this message translates to:
  /// **'{days} day{plural} after expected date'**
  String overduePaymentAlertSubtitle(int days, String plural);

  /// Auto-matching settings section title
  ///
  /// In en, this message translates to:
  /// **'Auto-Matching'**
  String get autoMatching;

  /// Auto-matching settings section footer
  ///
  /// In en, this message translates to:
  /// **'Fine-tune how the system matches actual payments to expected payments'**
  String get autoMatchingFooter;

  /// Amount tolerance setting title
  ///
  /// In en, this message translates to:
  /// **'Amount Tolerance'**
  String get amountTolerance;

  /// Amount tolerance setting subtitle
  ///
  /// In en, this message translates to:
  /// **'±{percent}% variance allowed'**
  String amountToleranceSubtitle(int percent);

  /// Date window setting title
  ///
  /// In en, this message translates to:
  /// **'Date Window'**
  String get dateWindow;

  /// Date window setting subtitle
  ///
  /// In en, this message translates to:
  /// **'±{days} day{plural} from expected date'**
  String dateWindowSubtitle(int days, String plural);

  /// Confidence threshold setting title
  ///
  /// In en, this message translates to:
  /// **'Confidence Threshold'**
  String get confidenceThreshold;

  /// Confidence threshold setting subtitle
  ///
  /// In en, this message translates to:
  /// **'{percent}% minimum match score'**
  String confidenceThresholdSubtitle(int percent);

  /// Platform delays settings section title
  ///
  /// In en, this message translates to:
  /// **'Platform Delays'**
  String get platformDelays;

  /// Platform delays settings section footer
  ///
  /// In en, this message translates to:
  /// **'Customize expected delays for specific platforms (e.g., LenDenClub +2 days)'**
  String get platformDelaysFooter;

  /// Coming soon label
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// Platform delays coming soon message
  ///
  /// In en, this message translates to:
  /// **'Platform-specific delay adjustments will be available in a future update'**
  String get platformDelaysComingSoon;

  /// Expected cash flow status: upcoming payment
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get incomeStatusUpcoming;

  /// Expected cash flow status: due soon
  ///
  /// In en, this message translates to:
  /// **'Due Soon'**
  String get incomeStatusDueSoon;

  /// Expected cash flow status: in grace period
  ///
  /// In en, this message translates to:
  /// **'Grace Period'**
  String get incomeStatusGracePeriod;

  /// Expected cash flow status: overdue payment
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get incomeStatusOverdue;

  /// Expected cash flow status: payment received
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get incomeStatusReceived;

  /// Expected cash flow status: dismissed by user
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get incomeStatusDismissed;

  /// Refresh button tooltip in income calendar
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get calendarRefresh;

  /// Error message when calendar fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load calendar'**
  String get calendarLoadFailed;

  /// Empty state message in income calendar
  ///
  /// In en, this message translates to:
  /// **'No expected payments this month'**
  String get calendarEmptyMessage;

  /// Calendar filter: show all payments
  ///
  /// In en, this message translates to:
  /// **'All Payments'**
  String get calendarFilterAllPayments;

  /// Calendar filter: show pending payments
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get calendarFilterPending;

  /// Calendar filter: show overdue payments
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get calendarFilterOverdue;

  /// Previous month button tooltip
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get calendarPreviousMonth;

  /// Next month button tooltip
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get calendarNextMonth;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get calendarRetry;

  /// No internet error message
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get calendarNoInternet;

  /// Income Guardian dashboard card title
  ///
  /// In en, this message translates to:
  /// **'Income Guardian'**
  String get dashboardIncomeGuardian;

  /// Next expected payment label on dashboard
  ///
  /// In en, this message translates to:
  /// **'Next Expected'**
  String get dashboardNextExpected;

  /// Dashboard message when no pending payments
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get dashboardAllCaughtUp;

  /// Pending payments count label
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get dashboardPending;

  /// Overdue payments count label
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get dashboardOverdue;

  /// Error message when dashboard fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load income data'**
  String get dashboardLoadFailed;

  /// Unknown investment name placeholder
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get dashboardUnknownInvestment;

  /// Loading state text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get dashboardLoading;

  /// Empty state message when showing all payments
  ///
  /// In en, this message translates to:
  /// **'No Expected Payments'**
  String get calendarScreenEmptyAll;

  /// Empty state message when showing pending payments
  ///
  /// In en, this message translates to:
  /// **'No Pending Payments'**
  String get calendarScreenEmptyPending;

  /// Empty state message when showing overdue payments
  ///
  /// In en, this message translates to:
  /// **'No Overdue Payments'**
  String get calendarScreenEmptyOverdue;

  /// Tooltip for previous month button
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get calendarGridPreviousMonth;

  /// Tooltip for next month button
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get calendarGridNextMonth;

  /// Header label for investment column
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get calendarGridInvestmentHeader;

  /// Fallback text when investment name cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get calendarGridUnknownInvestment;

  /// Label showing count of expected payments
  ///
  /// In en, this message translates to:
  /// **'{count} expected'**
  String calendarGridExpectedCount(int count);

  /// Title for payment details bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get calendarGridPaymentDetails;

  /// Label for expected payment date
  ///
  /// In en, this message translates to:
  /// **'Expected Date'**
  String get calendarGridExpectedDate;

  /// Label for expected payment amount
  ///
  /// In en, this message translates to:
  /// **'Expected Amount'**
  String get calendarGridExpectedAmount;

  /// Label for payment status
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get calendarGridStatus;

  /// Label for actual payment amount received
  ///
  /// In en, this message translates to:
  /// **'Actual Amount'**
  String get calendarGridActualAmount;

  /// Label for actual payment date received
  ///
  /// In en, this message translates to:
  /// **'Actual Date'**
  String get calendarGridActualDate;

  /// FAQ question about accessing income reports
  ///
  /// In en, this message translates to:
  /// **'How do I access Income Guardian reports?'**
  String get howToAccessIncomeReports;

  /// FAQ answer about accessing income reports
  ///
  /// In en, this message translates to:
  /// **'Income Trend reports are available in the Reports section. Navigate to Reports → Income Trend Analysis to see your monthly income trends, platform reliability scores, HHI diversification metrics, and auto-generated insights. Expected payment tracking will be available in the Dashboard (coming in Phase 2).'**
  String get howToAccessIncomeReportsAnswer;

  /// Advanced features section title in Help & FAQ
  ///
  /// In en, this message translates to:
  /// **'Advanced Features'**
  String get advancedFeatures;

  /// FAQ question about enabling debug mode
  ///
  /// In en, this message translates to:
  /// **'How do I enable debug mode?'**
  String get howToEnableDebugMode;

  /// FAQ answer about enabling debug mode
  ///
  /// In en, this message translates to:
  /// **'Tap the version number on the About screen 7 times within 3 seconds. This will reveal developer tools in Settings.'**
  String get howToEnableDebugModeAnswer;

  /// FAQ question about debug mode purpose
  ///
  /// In en, this message translates to:
  /// **'What is debug mode for?'**
  String get whatIsDebugModeFor;

  /// FAQ answer about debug mode purpose
  ///
  /// In en, this message translates to:
  /// **'Debug mode provides advanced tools for developers and power users, including sample data management and app diagnostics. It is useful for testing features and troubleshooting issues.'**
  String get whatIsDebugModeForAnswer;

  /// FAQ question about disabling debug mode
  ///
  /// In en, this message translates to:
  /// **'How do I disable debug mode?'**
  String get howToDisableDebugMode;

  /// FAQ answer about disabling debug mode
  ///
  /// In en, this message translates to:
  /// **'Tap the version number 7 times again, or toggle it off in Debug Settings under the Developer section in Settings.'**
  String get howToDisableDebugModeAnswer;

  /// App name
  ///
  /// In en, this message translates to:
  /// **'InvTrack'**
  String get invTrack;

  /// App version display
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({buildNumber})'**
  String version(String version, String buildNumber);

  /// Legal section title
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// Privacy policy title
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Terms of service title
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Support section title
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// Help & FAQ menu item
  ///
  /// In en, this message translates to:
  /// **'Help & FAQ'**
  String get helpAndFaq;

  /// Contact support title
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// Support email address
  ///
  /// In en, this message translates to:
  /// **'invtrack_support@googlegroups.com'**
  String get supportEmail;

  /// Subject line for support email
  ///
  /// In en, this message translates to:
  /// **'InvTrack Support Request (v{version})'**
  String supportEmailSubject(String version);

  /// Body text for support email
  ///
  /// In en, this message translates to:
  /// **'Please describe your issue or question:\n\n'**
  String get supportEmailBody;

  /// Message shown when email is copied to clipboard
  ///
  /// In en, this message translates to:
  /// **'Email copied to clipboard: {email}'**
  String emailCopiedMessage(String email);

  /// OK button label
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Error message when app info fails to load
  ///
  /// In en, this message translates to:
  /// **'Unable to load app information'**
  String get errorLoadingAppInfo;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Error message when Google sign-in fails
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String signInFailed(String error);

  /// Success message when anonymous account is linked to Google
  ///
  /// In en, this message translates to:
  /// **'Account linked successfully!'**
  String get accountLinkedSuccessfully;

  /// Error message when account linking fails
  ///
  /// In en, this message translates to:
  /// **'Linking failed: {error}'**
  String linkingFailed(String error);

  /// Error message when debug mode toggle fails
  ///
  /// In en, this message translates to:
  /// **'Failed to toggle debug mode'**
  String get debugModeActivationFailed;

  /// Footer message
  ///
  /// In en, this message translates to:
  /// **'Made with ❤️ for smart investors'**
  String get madeWithLove;

  /// Export failure message
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// Export success message
  ///
  /// In en, this message translates to:
  /// **'Export ready! Choose where to save.'**
  String get exportReady;

  /// Import strategy dialog title
  ///
  /// In en, this message translates to:
  /// **'Import Strategy'**
  String get importStrategy;

  /// Replace data confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Replace All Data?'**
  String get replaceAllData;

  /// Replace data confirmation message
  ///
  /// In en, this message translates to:
  /// **'This will DELETE all existing investments, goals, and documents and replace them with the imported data. This cannot be undone.'**
  String get replaceAllDataMessage;

  /// Replace all button label
  ///
  /// In en, this message translates to:
  /// **'Replace All'**
  String get replaceAll;

  /// Import partial success message
  ///
  /// In en, this message translates to:
  /// **'Import completed with errors: {error}'**
  String importCompletedWithErrors(String error);

  /// Import failure message
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// Seed demo data dialog title
  ///
  /// In en, this message translates to:
  /// **'Seed Demo Data?'**
  String get seedDemoData;

  /// Seed demo data dialog message
  ///
  /// In en, this message translates to:
  /// **'This will add 10 sample investments with realistic cash flows and goals. Great for testing!'**
  String get seedDemoDataMessage;

  /// Seed data button label
  ///
  /// In en, this message translates to:
  /// **'Seed Data'**
  String get seedData;

  /// Delete account option title
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// Delete account warning message
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete:\n\n• All investments & cash flows\n• All goals & progress\n• All documents & attachments\n• Your user profile\n\nThis action cannot be undone!'**
  String get deleteAccountMessage;

  /// Delete everything button label
  ///
  /// In en, this message translates to:
  /// **'Delete Everything'**
  String get deleteEverything;

  /// Account deletion cancelled message
  ///
  /// In en, this message translates to:
  /// **'Account deletion cancelled'**
  String get accountDeletionCancelled;

  /// Account deleted success message
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully'**
  String get accountDeletedSuccessfully;

  /// Account deletion failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account: {message}'**
  String failedToDeleteAccount(String message);

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error(String error);

  /// Final confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Final Confirmation'**
  String get finalConfirmation;

  /// Delete confirmation instruction
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm:'**
  String get typeDeleteToConfirm;

  /// Delete my account button label
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get deleteMyAccount;

  /// Merge investments dialog title
  ///
  /// In en, this message translates to:
  /// **'Merge Investments'**
  String get mergeInvestments;

  /// Merge investments dialog message
  ///
  /// In en, this message translates to:
  /// **'Merge {count} investments into one.'**
  String mergeInvestmentsMessage(int count);

  /// Merge button label
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// FIRE settings screen title
  ///
  /// In en, this message translates to:
  /// **'FIRE Settings'**
  String get fireSettings;

  /// No FIRE settings message
  ///
  /// In en, this message translates to:
  /// **'No FIRE settings found'**
  String get noFireSettingsFound;

  /// Set up FIRE button label
  ///
  /// In en, this message translates to:
  /// **'Set Up FIRE'**
  String get setUpFire;

  /// Basic settings section title
  ///
  /// In en, this message translates to:
  /// **'Basic Settings'**
  String get basicSettings;

  /// Advanced settings section title
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettings;

  /// Danger zone section title
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// Reset FIRE settings option
  ///
  /// In en, this message translates to:
  /// **'Reset FIRE Settings'**
  String get resetFireSettings;

  /// Reset FIRE settings subtitle
  ///
  /// In en, this message translates to:
  /// **'Start over with new settings'**
  String get startOverWithNewSettings;

  /// Age display
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String yearsAge(int age);

  /// Monthly expenses label
  ///
  /// In en, this message translates to:
  /// **'Monthly Expenses'**
  String get monthlyExpenses;

  /// Select FIRE type label
  ///
  /// In en, this message translates to:
  /// **'Select FIRE Type'**
  String get selectFireType;

  /// Percentage value display
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percentageValue(String value);

  /// Reset FIRE settings confirmation title
  ///
  /// In en, this message translates to:
  /// **'Reset FIRE Settings?'**
  String get resetFireSettingsConfirm;

  /// Reset FIRE settings confirmation message
  ///
  /// In en, this message translates to:
  /// **'This will delete all your FIRE settings. You will need to set them up again.'**
  String get resetFireSettingsMessage;

  /// Reset button label
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Try sample data button title
  ///
  /// In en, this message translates to:
  /// **'Try Sample Data'**
  String get trySampleData;

  /// Sample data description
  ///
  /// In en, this message translates to:
  /// **'Explore with realistic Indian investments'**
  String get exploreWithRealisticInvestments;

  /// Try it button label
  ///
  /// In en, this message translates to:
  /// **'Try It'**
  String get tryIt;

  /// Generic data load failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get failedToLoadData;

  /// Generic retry message
  ///
  /// In en, this message translates to:
  /// **'Please try again later'**
  String get pleaseTryAgainLater;

  /// Connection error title
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get connectionError;

  /// FIRE data load failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to load FIRE data. Please try again.'**
  String get failedToLoadFireData;

  /// FIRE settings load failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to load FIRE settings. Please try again.'**
  String get failedToLoadFireSettings;

  /// Investments load failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to load investments'**
  String get failedToLoadInvestments;

  /// Title for FIRE dashboard screen
  ///
  /// In en, this message translates to:
  /// **'FIRE Journey'**
  String get fireJourney;

  /// Button text to get started with a feature
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Button text to open document in external PDF viewer
  ///
  /// In en, this message translates to:
  /// **'Open in PDF Viewer'**
  String get openInPdfViewer;

  /// Button text to change selected file
  ///
  /// In en, this message translates to:
  /// **'Change File'**
  String get changeFile;

  /// Dialog title for permission requests
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permissionRequired;

  /// Button text to open device settings
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// Title for bulk import screen
  ///
  /// In en, this message translates to:
  /// **'Import Investments'**
  String get importInvestments;

  /// Title for import confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Confirm Import'**
  String get confirmImport;

  /// Button text to go back to previous screen
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// Button text to edit a goal
  ///
  /// In en, this message translates to:
  /// **'Edit Goal'**
  String get editGoal;

  /// Dialog title for goal deletion confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete Goal'**
  String get deleteGoal;

  /// Delete goal confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Goal?'**
  String get deleteGoalQuestion;

  /// Delete goal confirmation message
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete \"{goalName}\".'**
  String deleteGoalMessage(String goalName);

  /// Success message after deleting a goal
  ///
  /// In en, this message translates to:
  /// **'Goal deleted'**
  String get goalDeleted;

  /// Archive goal confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Archive Goal?'**
  String get archiveGoalQuestion;

  /// Archive goal confirmation message
  ///
  /// In en, this message translates to:
  /// **'\"{goalName}\" will be hidden from your active goals.'**
  String archiveGoalMessage(String goalName);

  /// Success message after archiving a goal
  ///
  /// In en, this message translates to:
  /// **'Goal archived'**
  String get goalArchived;

  /// Unarchive goal confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Unarchive Goal?'**
  String get unarchiveGoalQuestion;

  /// Unarchive goal confirmation message
  ///
  /// In en, this message translates to:
  /// **'\"{goalName}\" will be restored to your active goals.'**
  String unarchiveGoalMessage(String goalName);

  /// Success message after unarchiving a goal
  ///
  /// In en, this message translates to:
  /// **'Goal restored'**
  String get goalRestored;

  /// Empty state title for archived goals
  ///
  /// In en, this message translates to:
  /// **'No Archived Goals'**
  String get noArchivedGoals;

  /// Empty state message for archived goals
  ///
  /// In en, this message translates to:
  /// **'Archived goals will appear here'**
  String get archivedGoalsAppearHere;

  /// Error message when goals fail to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load goals. Please try again.'**
  String get failedToLoadGoals;

  /// Button text to view active goals
  ///
  /// In en, this message translates to:
  /// **'View active goals'**
  String get viewActiveGoals;

  /// Filter tab label for active goals
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterActive;

  /// Filter tab label for archived goals
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get filterArchived;

  /// Filter tab label for all investments
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// Filter tab label for open investments
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get filterOpen;

  /// Filter tab label for closed investments
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get filterClosed;

  /// Button text to create first goal
  ///
  /// In en, this message translates to:
  /// **'Create Your First Goal'**
  String get createYourFirstGoal;

  /// Empty state title for goals dashboard
  ///
  /// In en, this message translates to:
  /// **'Set Your First Goal'**
  String get setYourFirstGoal;

  /// Empty state subtitle for goals dashboard
  ///
  /// In en, this message translates to:
  /// **'Track progress towards your financial targets'**
  String get trackProgressTowardsTargets;

  /// Goals achievement badge showing completed vs total goals
  ///
  /// In en, this message translates to:
  /// **'{achieved}/{total} achieved'**
  String goalsAchieved(int achieved, int total);

  /// Badge label for completed goals in carousel
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get goalCompleted;

  /// Button text to update app now
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// Button text to add new investment
  ///
  /// In en, this message translates to:
  /// **'Add Investment'**
  String get addInvestment;

  /// Dialog title for clearing sample data
  ///
  /// In en, this message translates to:
  /// **'Clear Sample Data?'**
  String get clearSampleData;

  /// Button text to clear data
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Dialog title for keeping sample data
  ///
  /// In en, this message translates to:
  /// **'Keep Sample Data?'**
  String get keepSampleData;

  /// Button text to keep data
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// Title for premium paywall screen
  ///
  /// In en, this message translates to:
  /// **'InvTracker Premium'**
  String get invTrackerPremium;

  /// Button text to dismiss premium offer
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get maybeLater;

  /// Accessibility label for premium gate overlay
  ///
  /// In en, this message translates to:
  /// **'Unlock Premium feature'**
  String get unlockPremiumFeature;

  /// Tagline on sign-in screen
  ///
  /// In en, this message translates to:
  /// **'Track investments. Grow wealth.'**
  String get signInTagline;

  /// Terms and privacy policy text on sign-in screen
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our Terms of Service\nand Privacy Policy'**
  String get signInTermsText;

  /// Snackbar message when content is copied to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Accessibility hint for long-press to copy amount
  ///
  /// In en, this message translates to:
  /// **'Double tap and hold to copy exact amount'**
  String get doubleTapHoldToCopy;

  /// Google Sign-In button text
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Loading state text for sign-in button
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// Error message when Google Sign-In initialization fails
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize Google Sign-In. Please try again.'**
  String get googleSignInInitFailure;

  /// Success message when sample data is loaded
  ///
  /// In en, this message translates to:
  /// **'🧪 Sample data loaded! Explore the app.'**
  String get sampleDataLoaded;

  /// Error message when sample data fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load sample data. Please try again.'**
  String get sampleDataLoadFailed;

  /// Button label to download CSV template
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadTemplate;

  /// Button label to upload CSV file
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadCsv;

  /// Header for transaction type values legend
  ///
  /// In en, this message translates to:
  /// **'Type Values:'**
  String get typeValuesHeader;

  /// Success message when user upgrades to premium
  ///
  /// In en, this message translates to:
  /// **'Welcome to Premium!'**
  String get welcomeToPremium;

  /// Premium upgrade button text with price
  ///
  /// In en, this message translates to:
  /// **'Upgrade for \$4.99/mo'**
  String get upgradeForPrice;

  /// Emoji for goals empty state
  ///
  /// In en, this message translates to:
  /// **'🎯'**
  String get goalEmoji;

  /// Success message when document is deleted
  ///
  /// In en, this message translates to:
  /// **'Document deleted'**
  String get documentDeleted;

  /// Error message when document deletion fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete document'**
  String get failedToDeleteDocument;

  /// Error message when camera access fails
  ///
  /// In en, this message translates to:
  /// **'Could not access camera'**
  String get couldNotAccessCamera;

  /// Error message when file access fails
  ///
  /// In en, this message translates to:
  /// **'Could not access files'**
  String get couldNotAccessFiles;

  /// Success message when multiple documents are added
  ///
  /// In en, this message translates to:
  /// **'{count} documents added'**
  String documentsAdded(int count);

  /// Format for displaying age in years
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String yearsFormat(int age);

  /// Format for displaying percentage values
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percentageFormat(String value);

  /// Button text to add a document
  ///
  /// In en, this message translates to:
  /// **'Add Document'**
  String get addDocument;

  /// Button text to add a transaction
  ///
  /// In en, this message translates to:
  /// **'Add Transaction'**
  String get addTransaction;

  /// Success message when CSV template is ready
  ///
  /// In en, this message translates to:
  /// **'Template ready to share/save'**
  String get templateReadyToShare;

  /// Error message when template creation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to create template'**
  String get failedToCreateTemplate;

  /// Confirmation dialog title for deleting a transaction
  ///
  /// In en, this message translates to:
  /// **'Delete Transaction?'**
  String get deleteTransaction;

  /// Confirmation dialog title for deleting an investment
  ///
  /// In en, this message translates to:
  /// **'Delete Investment?'**
  String get deleteInvestment;

  /// Confirmation message for deleting an investment
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this investment and all its transactions. This action cannot be undone.'**
  String get deleteInvestmentMessage;

  /// Success message after investment is deleted
  ///
  /// In en, this message translates to:
  /// **'Investment deleted'**
  String get investmentDeleted;

  /// Error message when investment deletion fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete investment'**
  String get failedToDeleteInvestment;

  /// Error message when document file is not found
  ///
  /// In en, this message translates to:
  /// **'File not found. It may have been moved or deleted.'**
  String get fileNotFound;

  /// Bulk delete confirmation title
  ///
  /// In en, this message translates to:
  /// **'Delete {count} Investment{plural}?'**
  String deleteInvestmentsCount(int count, String plural);

  /// Warning message for irreversible actions
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get actionCannotBeUndone;

  /// Bulk delete goals confirmation title
  ///
  /// In en, this message translates to:
  /// **'Delete {count} Goal{plural}?'**
  String deleteGoalsCount(int count, String plural);

  /// Bulk delete goals confirmation message
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. The selected goal{plural} will be permanently deleted.'**
  String deleteGoalsMessage(String plural);

  /// Delete document confirmation title
  ///
  /// In en, this message translates to:
  /// **'Delete Document?'**
  String get deleteDocument;

  /// Delete document confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This cannot be undone.'**
  String deleteDocumentMessage(String name);

  /// Tooltip for back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get tooltipBack;

  /// Tooltip for close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get tooltipClose;

  /// Tooltip for go back button
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get tooltipGoBack;

  /// Tooltip for close setup button
  ///
  /// In en, this message translates to:
  /// **'Close setup'**
  String get tooltipCloseSetup;

  /// Tooltip for FIRE settings button
  ///
  /// In en, this message translates to:
  /// **'FIRE Settings'**
  String get tooltipFireSettings;

  /// Tooltip for decrease age button
  ///
  /// In en, this message translates to:
  /// **'Decrease age'**
  String get tooltipDecreaseAge;

  /// Tooltip for increase age button
  ///
  /// In en, this message translates to:
  /// **'Increase age'**
  String get tooltipIncreaseAge;

  /// Tooltip for decrease target age button
  ///
  /// In en, this message translates to:
  /// **'Decrease target age'**
  String get tooltipDecreaseTargetAge;

  /// Tooltip for increase target age button
  ///
  /// In en, this message translates to:
  /// **'Increase target age'**
  String get tooltipIncreaseTargetAge;

  /// Tooltip for clear target date button
  ///
  /// In en, this message translates to:
  /// **'Clear target date'**
  String get tooltipClearTargetDate;

  /// Tooltip for edit goal button
  ///
  /// In en, this message translates to:
  /// **'Edit Goal'**
  String get tooltipEditGoal;

  /// Tooltip for exit selection mode button
  ///
  /// In en, this message translates to:
  /// **'Exit selection'**
  String get tooltipExitSelection;

  /// Tooltip for select goals button
  ///
  /// In en, this message translates to:
  /// **'Select goals'**
  String get tooltipSelectGoals;

  /// Tooltip for add goal button
  ///
  /// In en, this message translates to:
  /// **'Add Goal'**
  String get tooltipAddGoal;

  /// Accessibility label for selecting a goal card in selection mode
  ///
  /// In en, this message translates to:
  /// **'Select {goalName}'**
  String selectGoalSemanticLabel(String goalName);

  /// Accessibility label for viewing goal card details
  ///
  /// In en, this message translates to:
  /// **'View details for {goalName}'**
  String viewGoalDetailsSemanticLabel(String goalName);

  /// Tooltip for more options button
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get tooltipMoreOptions;

  /// Tooltip for share document button
  ///
  /// In en, this message translates to:
  /// **'Share document'**
  String get tooltipShareDocument;

  /// Tooltip for toggle information button
  ///
  /// In en, this message translates to:
  /// **'Toggle information'**
  String get tooltipToggleInformation;

  /// Accessibility label for document viewer content area
  ///
  /// In en, this message translates to:
  /// **'Document content'**
  String get documentViewerContentLabel;

  /// Accessibility hint for resetting zoom in document viewer
  ///
  /// In en, this message translates to:
  /// **'Double tap to reset zoom'**
  String get documentViewerResetZoomHint;

  /// Accessibility action label for resetting zoom
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get documentViewerResetZoomAction;

  /// Accessibility label for document image
  ///
  /// In en, this message translates to:
  /// **'Document: {name}'**
  String documentSemanticLabel(String name);

  /// Accessibility label for PDF document viewer
  ///
  /// In en, this message translates to:
  /// **'PDF document: {name}'**
  String pdfDocumentLabel(String name);

  /// Tooltip for search investments button
  ///
  /// In en, this message translates to:
  /// **'Search investments'**
  String get tooltipSearchInvestments;

  /// Tooltip for clear text button
  ///
  /// In en, this message translates to:
  /// **'Clear text'**
  String get tooltipClearText;

  /// Tooltip for clear start date button
  ///
  /// In en, this message translates to:
  /// **'Clear start date'**
  String get tooltipClearStartDate;

  /// Tooltip for clear maturity date button
  ///
  /// In en, this message translates to:
  /// **'Clear maturity date'**
  String get tooltipClearMaturityDate;

  /// Hint text when maturity date is not set
  ///
  /// In en, this message translates to:
  /// **'No maturity date set'**
  String get hintNoMaturityDateSet;

  /// Semantic label for transaction date picker
  ///
  /// In en, this message translates to:
  /// **'Select transaction date'**
  String get semanticSelectTransactionDate;

  /// Hint text for search field
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get hintSearch;

  /// Hint text for delete confirmation field
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get hintDeleteConfirmation;

  /// Hint text for investment start date
  ///
  /// In en, this message translates to:
  /// **'When did you invest?'**
  String get hintWhenDidYouInvest;

  /// Archive action label
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// Unarchive action label
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// Saving progress indicator
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// Save multiple files button text
  ///
  /// In en, this message translates to:
  /// **'Save {count} Files'**
  String saveMultipleFiles(int count);

  /// App lock enabled confirmation message
  ///
  /// In en, this message translates to:
  /// **'App Lock enabled'**
  String get appLockEnabled;

  /// Error message when file is not found
  ///
  /// In en, this message translates to:
  /// **'File not found.'**
  String get fileNotFoundError;

  /// Error message when opening file fails
  ///
  /// In en, this message translates to:
  /// **'Error opening file: {message}'**
  String errorOpeningFile(String message);

  /// Error message when sharing document fails
  ///
  /// In en, this message translates to:
  /// **'Failed to share document: {error}'**
  String failedToShareDocument(String error);

  /// Success message when investments are merged
  ///
  /// In en, this message translates to:
  /// **'Investments merged into \"{name}\"'**
  String investmentsMerged(String name);

  /// Debug mode label
  ///
  /// In en, this message translates to:
  /// **'Debug Mode'**
  String get debugMode;

  /// Debug settings screen title
  ///
  /// In en, this message translates to:
  /// **'Debug Settings'**
  String get debugSettings;

  /// Debug settings subtitle
  ///
  /// In en, this message translates to:
  /// **'Advanced tools & diagnostics'**
  String get advancedToolsAndDiagnostics;

  /// Toggle to enable debug mode
  ///
  /// In en, this message translates to:
  /// **'Enable Debug Mode'**
  String get enableDebugMode;

  /// Toast message when debug mode is enabled
  ///
  /// In en, this message translates to:
  /// **'🛠️ Debug mode enabled'**
  String get debugModeEnabled;

  /// Toast message when debug mode is disabled
  ///
  /// In en, this message translates to:
  /// **'Debug mode disabled'**
  String get debugModeDisabled;

  /// Description of what debug mode does
  ///
  /// In en, this message translates to:
  /// **'Show developer tools and diagnostics'**
  String get debugModeDescription;

  /// App information section
  ///
  /// In en, this message translates to:
  /// **'App Info'**
  String get appInfo;

  /// Diagnostics section title
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// Developer section title
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// Sample data section title
  ///
  /// In en, this message translates to:
  /// **'Sample Data'**
  String get sampleData;

  /// Confirmation dialog for clearing sample data
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all sample data?'**
  String get confirmClearSampleData;

  /// Success message after clearing sample data
  ///
  /// In en, this message translates to:
  /// **'Sample data cleared successfully'**
  String get sampleDataCleared;

  /// Hint for enabling debug mode
  ///
  /// In en, this message translates to:
  /// **'Tap version 7 times to enable debug mode'**
  String get tapVersionToEnable;

  /// App version label
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// Build number label
  ///
  /// In en, this message translates to:
  /// **'Build Number'**
  String get buildNumber;

  /// Platform label (iOS/Android)
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// Device information label
  ///
  /// In en, this message translates to:
  /// **'Device Info'**
  String get deviceInfo;

  /// Subtitle for seed demo data button
  ///
  /// In en, this message translates to:
  /// **'Add sample investments'**
  String get addSampleInvestments;

  /// Subtitle for clear sample data button
  ///
  /// In en, this message translates to:
  /// **'Delete all sample investments and goals'**
  String get deleteSampleInvestments;

  /// Subtitle for app info button
  ///
  /// In en, this message translates to:
  /// **'View app version and device details'**
  String get viewAppInformation;

  /// Success message after seeding sample data
  ///
  /// In en, this message translates to:
  /// **'Sample data added successfully'**
  String get sampleDataSeeded;

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Message when there is no sample data to delete
  ///
  /// In en, this message translates to:
  /// **'No sample data to clear'**
  String get noSampleDataToClear;

  /// Button text to continue using the app without signing in
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// Notice shown when user enters guest mode explaining anonymous cloud storage and uninstall data-loss risk (GDPR Article 13)
  ///
  /// In en, this message translates to:
  /// **'Your data is saved to the cloud as a guest. Sign in to secure it across devices — uninstalling the app may cause data loss.'**
  String get guestModeNotice;

  /// Indicator shown in settings when user is in guest mode with anonymous account
  ///
  /// In en, this message translates to:
  /// **'Guest Mode (Anonymous Account)'**
  String get guestModeIndicator;

  /// Call-to-action for guest users to sign in and link their anonymous data to a permanent account
  ///
  /// In en, this message translates to:
  /// **'Sign In to Link Account'**
  String get signInToBackup;

  /// Option to delete all guest data from cloud and local storage
  ///
  /// In en, this message translates to:
  /// **'Delete Guest Data'**
  String get deleteGuestData;

  /// Confirmation message before deleting guest data explaining cloud and account deletion
  ///
  /// In en, this message translates to:
  /// **'Are you sure? This will permanently delete all your data from cloud and local storage, and remove your anonymous account.'**
  String get deleteGuestDataConfirm;

  /// Success message after guest data and anonymous account are deleted
  ///
  /// In en, this message translates to:
  /// **'Guest data and anonymous account deleted successfully'**
  String get guestDataDeleted;

  /// Error message when guest data deletion fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete guest data. Please try again.'**
  String get guestDataDeletionFailed;

  /// Guest mode section title in Help & FAQ
  ///
  /// In en, this message translates to:
  /// **'Guest Mode'**
  String get guestModeSection;

  /// FAQ question about guest mode
  ///
  /// In en, this message translates to:
  /// **'What is Guest Mode?'**
  String get whatIsGuestMode;

  /// FAQ answer about guest mode
  ///
  /// In en, this message translates to:
  /// **'Guest Mode lets you use InvTrack without signing in. Your data is stored in the cloud under an anonymous account, so you can access it across devices. You can sign in later to link this data to your Google account.'**
  String get whatIsGuestModeAnswer;

  /// FAQ question about linking guest account
  ///
  /// In en, this message translates to:
  /// **'How do I link my guest account to Google?'**
  String get howToLinkGuestAccount;

  /// FAQ answer about linking guest account
  ///
  /// In en, this message translates to:
  /// **'Tap the \'\'Sign In to Link Account\'\' button in Settings. If your Google account already exists, we\'\'ll create a backup of your guest data first, then you can import it after signing in.'**
  String get howToLinkGuestAccountAnswer;

  /// FAQ question about guest data after sign-in
  ///
  /// In en, this message translates to:
  /// **'What happens to my guest data when I sign in?'**
  String get whatHappensToGuestData;

  /// FAQ answer about guest data after sign-in
  ///
  /// In en, this message translates to:
  /// **'If your Google account is new, your guest data is automatically linked to it. If your Google account already exists, we create a ZIP backup of your guest data, which you can import to merge with your existing data.'**
  String get whatHappensToGuestDataAnswer;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Success message when currency is switched
  ///
  /// In en, this message translates to:
  /// **'Currency switched to {currency}'**
  String currencySwitchedSuccessfully(String currency);

  /// Error message when currency switch fails
  ///
  /// In en, this message translates to:
  /// **'Failed to switch to {currency}. Please try again.'**
  String currencySwitchFailed(String currency);

  /// Loading progress indicator with counts
  ///
  /// In en, this message translates to:
  /// **'Loading: {fetched} of {total}'**
  String loadingProgress(int fetched, int total);

  /// US Dollar currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'US Dollar (\$)'**
  String get currencyUSD;

  /// Euro currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'Euro (€)'**
  String get currencyEUR;

  /// British Pound currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'British Pound (£)'**
  String get currencyGBP;

  /// Indian Rupee currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'Indian Rupee (₹)'**
  String get currencyINR;

  /// Japanese Yen currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'Japanese Yen (¥)'**
  String get currencyJPY;

  /// Canadian Dollar currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'Canadian Dollar (C\$)'**
  String get currencyCAD;

  /// Australian Dollar currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'Australian Dollar (A\$)'**
  String get currencyAUD;

  /// Swiss Franc currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'Swiss Franc (CHF)'**
  String get currencyCHF;

  /// Chinese Yuan currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'Chinese Yuan (¥)'**
  String get currencyCNY;

  /// Singapore Dollar currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'Singapore Dollar (S\$)'**
  String get currencySGD;

  /// Hong Kong Dollar currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'Hong Kong Dollar (HK\$)'**
  String get currencyHKD;

  /// Brazilian Real currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'Brazilian Real (R\$)'**
  String get currencyBRL;

  /// Mexican Peso currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'Mexican Peso (MX\$)'**
  String get currencyMXN;

  /// South African Rand currency name with symbol
  ///
  /// In en, this message translates to:
  /// **'South African Rand (R)'**
  String get currencyZAR;

  /// Header text for import confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Ready to Import'**
  String get readyToImport;

  /// Title for FIRE setup screen
  ///
  /// In en, this message translates to:
  /// **'FIRE Setup'**
  String get fireSetup;

  /// Title for create goal screen
  ///
  /// In en, this message translates to:
  /// **'Create Goal'**
  String get createGoal;

  /// Button text to share a document or item
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Button text to add investment manually
  ///
  /// In en, this message translates to:
  /// **'Add Manually'**
  String get addManually;

  /// Sublabel for add manually button
  ///
  /// In en, this message translates to:
  /// **'Step by step'**
  String get stepByStep;

  /// Button text to import CSV file
  ///
  /// In en, this message translates to:
  /// **'Import CSV'**
  String get importCsv;

  /// Sublabel for import CSV button
  ///
  /// In en, this message translates to:
  /// **'Bulk upload'**
  String get bulkUpload;

  /// Button text to go to next step
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Confirmation message when clearing sample data
  ///
  /// In en, this message translates to:
  /// **'This will remove all sample investments and goals. You can always try sample data again later.'**
  String get sampleDataRemovalConfirmation;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorOccurred(String error);

  /// Title for sample data mode banner
  ///
  /// In en, this message translates to:
  /// **'Sample Data Mode'**
  String get sampleDataMode;

  /// Subtitle for sample data mode banner
  ///
  /// In en, this message translates to:
  /// **'Exploring with sample investments'**
  String get exploringWithSampleInvestments;

  /// Confirmation message when keeping sample data as real data
  ///
  /// In en, this message translates to:
  /// **'Sample investments will become your real data. You can edit or delete them anytime.'**
  String get sampleDataKeepConfirmation;

  /// Empty state title when search returns no results
  ///
  /// In en, this message translates to:
  /// **'No Results Found'**
  String get noResultsFound;

  /// Empty state message when search returns no results
  ///
  /// In en, this message translates to:
  /// **'Try searching with a different term'**
  String get tryDifferentSearchTerm;

  /// Empty state title for archived investments
  ///
  /// In en, this message translates to:
  /// **'No Archived Investments'**
  String get noArchivedInvestments;

  /// Empty state message for archived investments
  ///
  /// In en, this message translates to:
  /// **'Investments you archive will appear here'**
  String get archivedInvestmentsAppearHere;

  /// Empty state title when filter returns no results
  ///
  /// In en, this message translates to:
  /// **'No Matching Investments'**
  String get noMatchingInvestments;

  /// Empty state message when filter returns no results
  ///
  /// In en, this message translates to:
  /// **'Try a different filter'**
  String get tryDifferentFilter;

  /// Empty state message when no investments exist
  ///
  /// In en, this message translates to:
  /// **'No investments found'**
  String get noInvestmentsFound;

  /// Net position label
  ///
  /// In en, this message translates to:
  /// **'Net Position'**
  String get netPosition;

  /// Message shown when trying to use bulk operations on archived goals
  ///
  /// In en, this message translates to:
  /// **'Bulk operations are not available for archived goals.\nUse swipe actions to delete or unarchive individual items.'**
  String get bulkOpsNotAvailableForArchived;

  /// Label for new investment name field in merge dialog
  ///
  /// In en, this message translates to:
  /// **'New Investment Name'**
  String get newInvestmentName;

  /// Hint for new investment name field in merge dialog
  ///
  /// In en, this message translates to:
  /// **'Enter name for merged investment'**
  String get enterNameForMergedInvestment;

  /// Filter label for investment type
  ///
  /// In en, this message translates to:
  /// **'Investment Type'**
  String get investmentType;

  /// Title for force update dialog
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get updateRequired;

  /// Title for optional update dialog
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// Default message for update dialog
  ///
  /// In en, this message translates to:
  /// **'A new version of InvTrack is available!'**
  String get newVersionAvailableMessage;

  /// Semantic label for privacy-masked amounts
  ///
  /// In en, this message translates to:
  /// **'Hidden amount'**
  String get hiddenAmount;

  /// Portfolio health report title
  ///
  /// In en, this message translates to:
  /// **'Portfolio Health'**
  String get portfolioHealth;

  /// Portfolio health score title
  ///
  /// In en, this message translates to:
  /// **'Portfolio Health Score'**
  String get portfolioHealthScore;

  /// Portfolio health details screen title
  ///
  /// In en, this message translates to:
  /// **'Portfolio Health Details'**
  String get portfolioHealthDetails;

  /// Message when portfolio health data is not available
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noPortfolioData;

  /// Empty state message for portfolio health
  ///
  /// In en, this message translates to:
  /// **'Add investments to see your portfolio health score'**
  String get addInvestmentsToSeeHealth;

  /// Health score trend chart title with weeks count
  ///
  /// In en, this message translates to:
  /// **'Score Trend (Last {weeks} Weeks)'**
  String healthScoreTrendWeeks(int weeks);

  /// Message when there's no trend data
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get healthScoreTrendNoData;

  /// Message to check back later for trend data
  ///
  /// In en, this message translates to:
  /// **'Check back in a week to see your trend'**
  String get healthScoreTrendCheckBack;

  /// Button to hide details
  ///
  /// In en, this message translates to:
  /// **'Hide Details'**
  String get hideDetails;

  /// Button to show details
  ///
  /// In en, this message translates to:
  /// **'Show Details'**
  String get showDetails;

  /// Historical trend section title
  ///
  /// In en, this message translates to:
  /// **'Historical Trend'**
  String get historicalTrend;

  /// Component breakdown section title
  ///
  /// In en, this message translates to:
  /// **'Component Breakdown'**
  String get componentBreakdown;

  /// Top suggestions section title
  ///
  /// In en, this message translates to:
  /// **'Top Suggestions'**
  String get topSuggestions;

  /// Snackbar message when score is copied
  ///
  /// In en, this message translates to:
  /// **'Score copied to clipboard'**
  String get scoreCopiedToClipboard;

  /// Positive score improvement badge
  ///
  /// In en, this message translates to:
  /// **'+{points} pts'**
  String scoreImprovementPositive(int points);

  /// Negative score improvement badge (already has minus sign in number)
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String scoreImprovementNegative(int points);

  /// Experimental features section title
  ///
  /// In en, this message translates to:
  /// **'Experimental Features'**
  String get experimentalFeatures;

  /// Portfolio health score feature toggle title
  ///
  /// In en, this message translates to:
  /// **'Portfolio Health Score'**
  String get portfolioHealthScoreFeature;

  /// Portfolio health score feature description
  ///
  /// In en, this message translates to:
  /// **'Unified health score (0-100) with trend chart'**
  String get portfolioHealthScoreSubtitle;

  /// Message when feature is enabled
  ///
  /// In en, this message translates to:
  /// **'Portfolio Health Score enabled'**
  String get portfolioHealthScoreEnabled;

  /// Message when feature is disabled
  ///
  /// In en, this message translates to:
  /// **'Portfolio Health Score disabled'**
  String get portfolioHealthScoreDisabled;

  /// Reports tab feature toggle title
  ///
  /// In en, this message translates to:
  /// **'Reports Tab'**
  String get reportsTabFeature;

  /// Reports tab feature description
  ///
  /// In en, this message translates to:
  /// **'Smart Insights and DIY Report Builder'**
  String get reportsTabSubtitle;

  /// Message when Reports tab is enabled
  ///
  /// In en, this message translates to:
  /// **'Reports tab enabled - restart app to see changes'**
  String get reportsTabEnabled;

  /// Message when Reports tab is disabled
  ///
  /// In en, this message translates to:
  /// **'Reports tab disabled - restart app to see changes'**
  String get reportsTabDisabled;

  /// Income Guardian feature toggle title
  ///
  /// In en, this message translates to:
  /// **'Income Guardian'**
  String get incomeGuardianFeature;

  /// Income Guardian feature description
  ///
  /// In en, this message translates to:
  /// **'AI-powered income tracking with payment monitoring'**
  String get incomeGuardianFeatureSubtitle;

  /// Snackbar message when Income Guardian is enabled
  ///
  /// In en, this message translates to:
  /// **'Income Guardian enabled'**
  String get incomeGuardianFeatureEnabled;

  /// Snackbar message when Income Guardian is disabled
  ///
  /// In en, this message translates to:
  /// **'Income Guardian disabled'**
  String get incomeGuardianFeatureDisabled;

  /// Beta badge for Income Guardian feature
  ///
  /// In en, this message translates to:
  /// **'BETA'**
  String get dashboardIncomeGuardianBeta;

  /// Income Guardian dashboard card subtitle
  ///
  /// In en, this message translates to:
  /// **'AI-powered income tracking'**
  String get dashboardIncomeGuardianSubtitle;

  /// Overdue payment badge label
  ///
  /// In en, this message translates to:
  /// **'OVERDUE'**
  String get dashboardOverdueBadge;

  /// Due date label in payment card
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dashboardDueDate;

  /// Source label in payment card
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get dashboardSource;

  /// Empty state message when no pending payments
  ///
  /// In en, this message translates to:
  /// **'No pending income payments'**
  String get dashboardNoPendingPayments;

  /// Empty state badge when all income is on track
  ///
  /// In en, this message translates to:
  /// **'All income on track'**
  String get dashboardAllIncomeOnTrack;

  /// Accessibility label for positive score change
  ///
  /// In en, this message translates to:
  /// **'Score improved'**
  String get healthScoreImproved;

  /// Accessibility label for negative score change
  ///
  /// In en, this message translates to:
  /// **'Score declined'**
  String get healthScoreDeclined;

  /// Accessibility label for health score display
  ///
  /// In en, this message translates to:
  /// **'Portfolio health score {score} out of 100'**
  String healthScoreOutOf100(int score);

  /// Share text for portfolio health score
  ///
  /// In en, this message translates to:
  /// **'My InvTrack Portfolio Health Score: {score}/100 ({tier})\n\n📊 Component Scores:\n- Returns: {returns}/100\n- Diversification: {diversification}/100\n- Liquidity: {liquidity}/100\n- Goals: {goals}/100\n- Actions: {actions}/100\n\nTrack your investments with InvTrack!'**
  String shareScoreText(
    int score,
    String tier,
    int returns,
    int diversification,
    int liquidity,
    int goals,
    int actions,
  );

  /// FAQ section title for portfolio health
  ///
  /// In en, this message translates to:
  /// **'Portfolio Health Score'**
  String get portfolioHealthSection;

  /// FAQ question about portfolio health score
  ///
  /// In en, this message translates to:
  /// **'What is the Portfolio Health Score?'**
  String get whatIsPortfolioHealthScore;

  /// FAQ answer explaining portfolio health score
  ///
  /// In en, this message translates to:
  /// **'Portfolio Health Score is like a Fitbit for your money - a single number (0-100) that tells you how healthy your investments are. It analyzes 5 key areas: Returns (30%), Diversification (25%), Liquidity (20%), Goal Alignment (15%), and Action Readiness (10%). Think of it as your portfolio\'\'s credit score!'**
  String get whatIsPortfolioHealthScoreAnswer;

  /// FAQ question about enabling portfolio health
  ///
  /// In en, this message translates to:
  /// **'How do I enable Portfolio Health Score?'**
  String get howToEnablePortfolioHealth;

  /// FAQ answer about enabling portfolio health
  ///
  /// In en, this message translates to:
  /// **'Go to Settings → Debug Settings → Experimental Features and toggle \'\'Portfolio Health Score\'\' ON. The feature is currently in beta testing. You\'\'ll see your health score on the overview screen if you have investments.'**
  String get howToEnablePortfolioHealthAnswer;

  /// FAQ question about score tiers
  ///
  /// In en, this message translates to:
  /// **'What do the score tiers mean?'**
  String get whatDoScoreTiersMean;

  /// FAQ answer explaining score tiers
  ///
  /// In en, this message translates to:
  /// **'Scores are categorized into 4 tiers:\n\n💚 Excellent (80-100): Your portfolio is thriving! Keep up the good work.\n\n💛 Good (60-79): Solid foundation with minor improvements possible.\n\n🧡 Fair (40-59): Attention needed. Review the suggestions.\n\n❤️ Poor (0-39): Urgent action required to improve portfolio health.'**
  String get whatDoScoreTiersMeanAnswer;

  /// FAQ question about improving score
  ///
  /// In en, this message translates to:
  /// **'How can I improve my health score?'**
  String get howToImproveMyScore;

  /// FAQ answer about improving score
  ///
  /// In en, this message translates to:
  /// **'Tap on your health score card to see detailed component scores and personalized suggestions. Each component (Returns, Diversification, Liquidity, Goals, Actions) shows specific recommendations to improve your portfolio health. Focus on the components with the lowest scores first.'**
  String get howToImproveMyScoreAnswer;

  /// FAQ question about score persistence
  ///
  /// In en, this message translates to:
  /// **'Is my health score data saved?'**
  String get isHealthScoreDataSaved;

  /// FAQ answer about score persistence
  ///
  /// In en, this message translates to:
  /// **'Yes! Your health scores are automatically saved in your Firebase account and synced across devices. You can view your score trend over time in the details screen. Score history is included in data exports and deleted when you delete your account.'**
  String get isHealthScoreDataSavedAnswer;

  /// Error message when health score chart data fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load chart data'**
  String get failedToLoadChartData;

  /// Generic message to retry an operation
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get pleaseTryAgain;

  /// Button text to retry an operation
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// Error message when report generation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to generate report'**
  String get failedToGenerateReport;

  /// Crashlytics testing section title
  ///
  /// In en, this message translates to:
  /// **'Crashlytics Testing'**
  String get crashlyticsTestingTitle;

  /// Toggle title for enabling Crashlytics in debug mode
  ///
  /// In en, this message translates to:
  /// **'Enable Crashlytics in Debug Mode'**
  String get enableCrashlyticsInDebugTitle;

  /// Subtitle when Crashlytics is enabled
  ///
  /// In en, this message translates to:
  /// **'Crashlytics is enabled - errors will be reported'**
  String get crashlyticsEnabledSubtitle;

  /// Subtitle when Crashlytics is disabled
  ///
  /// In en, this message translates to:
  /// **'Enable to test crash reporting in debug builds'**
  String get crashlyticsDisabledSubtitle;

  /// Snackbar message when Crashlytics is enabled
  ///
  /// In en, this message translates to:
  /// **'Crashlytics enabled in debug mode'**
  String get crashlyticsEnabledSnack;

  /// Snackbar message when Crashlytics is disabled
  ///
  /// In en, this message translates to:
  /// **'Crashlytics disabled in debug mode'**
  String get crashlyticsDisabledSnack;

  /// Title for test non-fatal error button
  ///
  /// In en, this message translates to:
  /// **'Test Non-Fatal Error'**
  String get testNonFatalTitle;

  /// Subtitle for test non-fatal error button
  ///
  /// In en, this message translates to:
  /// **'Send a test error to Firebase Crashlytics'**
  String get testNonFatalSubtitle;

  /// Title for test fatal crash button
  ///
  /// In en, this message translates to:
  /// **'Test Fatal Crash'**
  String get testFatalTitle;

  /// Subtitle for test fatal crash button
  ///
  /// In en, this message translates to:
  /// **'⚠️ This will crash the app!'**
  String get testFatalSubtitle;

  /// Dialog title for test non-fatal error
  ///
  /// In en, this message translates to:
  /// **'Test Non-Fatal Error'**
  String get testNonFatalDialogTitle;

  /// Dialog message for test non-fatal error
  ///
  /// In en, this message translates to:
  /// **'This will send a test non-fatal error to Firebase Crashlytics. The error will appear in your Firebase Console within a few minutes.\n\nContinue?'**
  String get testNonFatalDialogMessage;

  /// Button text to send test error
  ///
  /// In en, this message translates to:
  /// **'Send Test Error'**
  String get sendTestError;

  /// Success message when test error is sent
  ///
  /// In en, this message translates to:
  /// **'Test error sent to Crashlytics! Check Firebase Console in 5 minutes.'**
  String get testErrorSentSuccess;

  /// Dialog title for test fatal crash
  ///
  /// In en, this message translates to:
  /// **'Test Fatal Crash'**
  String get testFatalDialogTitle;

  /// Dialog message for test fatal crash
  ///
  /// In en, this message translates to:
  /// **'⚠️ WARNING: This will CRASH the app immediately!\n\nThe crash will be reported to Firebase Crashlytics and you will need to restart the app.\n\nOnly use this to verify Crashlytics is working correctly.\n\nContinue?'**
  String get testFatalDialogMessage;

  /// Button text to crash the app now
  ///
  /// In en, this message translates to:
  /// **'Crash Now'**
  String get crashNow;

  /// Warning message when Crashlytics is disabled
  ///
  /// In en, this message translates to:
  /// **'Crashlytics is disabled in debug mode. Enable it in the toggle above to test crash reporting.'**
  String get crashlyticsDisabledWarning;

  /// Banner title when Crashlytics is enabled in debug mode
  ///
  /// In en, this message translates to:
  /// **'Crashlytics Active in Debug Mode'**
  String get crashlyticsActiveInDebugTitle;

  /// Banner title when Crashlytics is disabled in debug mode
  ///
  /// In en, this message translates to:
  /// **'Crashlytics Inactive in Debug Mode'**
  String get crashlyticsInactiveInDebugTitle;

  /// Banner message when Crashlytics is enabled in debug mode
  ///
  /// In en, this message translates to:
  /// **'Crash reports are being sent to Firebase. You can test by clicking \"Test Fatal Crash\" below.'**
  String get crashlyticsActiveInDebugMessage;

  /// Banner message when Crashlytics is disabled in debug mode
  ///
  /// In en, this message translates to:
  /// **'Crash reports are NOT being sent (debug mode default). Enable toggle above to test crash reporting.'**
  String get crashlyticsInactiveInDebugMessage;

  /// Note that Crashlytics works in release builds regardless of debug mode setting
  ///
  /// In en, this message translates to:
  /// **'✓ Crashlytics works automatically in release builds'**
  String get crashlyticsWorksInReleaseNote;

  /// Button title to manually check for app updates
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdatesTitle;

  /// Loading text when checking for updates
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get checkingForUpdates;

  /// Message shown when app is on the latest version
  ///
  /// In en, this message translates to:
  /// **'App is up to date'**
  String get appIsUpToDate;

  /// Message asking user if they want to update the app
  ///
  /// In en, this message translates to:
  /// **'A new version of InvTrack is available. Would you like to update now?'**
  String get updatePromptMessage;

  /// Button text to postpone an action
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// Button text to start update
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// Message shown when update is downloading in background
  ///
  /// In en, this message translates to:
  /// **'Downloading update in background...'**
  String get downloadingUpdateBackground;

  /// Message for critical/mandatory updates
  ///
  /// In en, this message translates to:
  /// **'A critical update is available. Please update now.'**
  String get criticalUpdateMessage;

  /// Title for in-app update install dialog
  ///
  /// In en, this message translates to:
  /// **'Update Ready'**
  String get inAppUpdateInstallTitle;

  /// Message for in-app update install dialog
  ///
  /// In en, this message translates to:
  /// **'Update has been downloaded. Restart the app to install?'**
  String get inAppUpdateInstallMessage;

  /// Button text to restart and install update
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get inAppUpdateInstallButton;

  /// Text indicating something has never occurred
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// Reports tab/screen title
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// Subtitle for weekly summary report
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// Monthly income report title
  ///
  /// In en, this message translates to:
  /// **'Monthly Income'**
  String get monthlyIncome;

  /// Subtitle for monthly income report
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// Financial Year report title
  ///
  /// In en, this message translates to:
  /// **'FY Report'**
  String get fyReport;

  /// Performance analysis report title
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performance;

  /// Full title for performance report
  ///
  /// In en, this message translates to:
  /// **'Performance Report'**
  String get performanceReport;

  /// Full title for goals report
  ///
  /// In en, this message translates to:
  /// **'Goals Report'**
  String get goalsReport;

  /// Full title for maturity calendar
  ///
  /// In en, this message translates to:
  /// **'Maturity Calendar'**
  String get maturityCalendar;

  /// Subtitle for performance report
  ///
  /// In en, this message translates to:
  /// **'Top Performers'**
  String get topPerformers;

  /// Maturity calendar report title
  ///
  /// In en, this message translates to:
  /// **'Maturity'**
  String get maturity;

  /// Subtitle for maturity calendar
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// Action required report title
  ///
  /// In en, this message translates to:
  /// **'Action Required'**
  String get actionRequired;

  /// Quick reports section title on reports home screen
  ///
  /// In en, this message translates to:
  /// **'Quick Reports'**
  String get quickReports;

  /// Current financial year label (e.g., FY 2023-24)
  ///
  /// In en, this message translates to:
  /// **'FY {year1}-{year2}'**
  String currentFY(String year1, String year2);

  /// Financial year label format (e.g., FY 2023-24)
  ///
  /// In en, this message translates to:
  /// **'FY {startYear}-{endYear}'**
  String fyLabel(String startYear, String endYear);

  /// Status showing how many payments have been received out of total expected
  ///
  /// In en, this message translates to:
  /// **'{receivedCount} of {totalCount} payments received'**
  String paymentsReceived(int receivedCount, int totalCount);

  /// Label prefix showing amount invested (e.g., 'Invested: ₹1L')
  ///
  /// In en, this message translates to:
  /// **'Invested: '**
  String get invested;

  /// Button/link text to view more details
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// Message shown when a list has no items to show
  ///
  /// In en, this message translates to:
  /// **'No items to display'**
  String get noItemsToDisplay;

  /// Label for closed investments
  ///
  /// In en, this message translates to:
  /// **'CLOSED'**
  String get closed;

  /// Cash flow entries count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String cashFlowEntries(int count);

  /// Shows when investment was added relative to now (e.g., 'Added 2 days ago')
  ///
  /// In en, this message translates to:
  /// **'Added {relativeTime}'**
  String addedRelative(String relativeTime);

  /// Filter chip label for showing all payments
  ///
  /// In en, this message translates to:
  /// **'All Payments'**
  String get allPaymentsFilter;

  /// Filter chip label for showing pending payments
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingFilter;

  /// Filter chip label for showing overdue payments
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueFilter;

  /// Active goals count for reports home screen
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No Active Goals} =1{1 Active Goal} other{{count} Active Goals}}'**
  String activeGoalsCount(int count);

  /// Action items count for reports home screen
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No Items} =1{1 Item} other{{count} Items}}'**
  String actionItemsCount(int count);

  /// Portfolio health score label
  ///
  /// In en, this message translates to:
  /// **'Score: {score}/100'**
  String healthScore(int score);

  /// Section title for daily cashflow trend chart in weekly summary
  ///
  /// In en, this message translates to:
  /// **'Daily Cashflow Trend'**
  String get dailyCashflowTrend;

  /// Historical reports section title
  ///
  /// In en, this message translates to:
  /// **'Historical Reports'**
  String get historicalReports;

  /// Empty state message for historical reports
  ///
  /// In en, this message translates to:
  /// **'No historical reports yet'**
  String get noHistoricalReportsYet;

  /// Section title for FY reports in historical reports list
  ///
  /// In en, this message translates to:
  /// **'Financial Year Reports'**
  String get financialYearReports;

  /// Section title for monthly reports in historical reports list
  ///
  /// In en, this message translates to:
  /// **'Monthly Reports'**
  String get monthlyReports;

  /// Label for current financial year
  ///
  /// In en, this message translates to:
  /// **'Current Year'**
  String get currentYear;

  /// Label for current month
  ///
  /// In en, this message translates to:
  /// **'Current Month'**
  String get currentMonth;

  /// Hint text for tappable list items
  ///
  /// In en, this message translates to:
  /// **'Tap to view'**
  String get tapToView;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get january;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get february;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get march;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get april;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get june;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get july;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get august;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get september;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get october;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get november;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get december;

  /// Tooltip for export button
  ///
  /// In en, this message translates to:
  /// **'Export Report'**
  String get exportReport;

  /// Export as CSV option title
  ///
  /// In en, this message translates to:
  /// **'Export as CSV'**
  String get exportAsCsv;

  /// Description for CSV export
  ///
  /// In en, this message translates to:
  /// **'For spreadsheet apps'**
  String get forSpreadsheetApps;

  /// PDF export menu item
  ///
  /// In en, this message translates to:
  /// **'Export as PDF'**
  String get exportAsPdf;

  /// Description for PDF export
  ///
  /// In en, this message translates to:
  /// **'For sharing & printing'**
  String get forSharingAndPrinting;

  /// Success message for CSV export
  ///
  /// In en, this message translates to:
  /// **'CSV exported successfully ({size} KB)'**
  String csvExportedSuccessfully(String size);

  /// Success message for PDF export
  ///
  /// In en, this message translates to:
  /// **'PDF exported successfully ({size} KB)'**
  String pdfExportedSuccessfully(String size);

  /// Error message for CSV export failure
  ///
  /// In en, this message translates to:
  /// **'Failed to export CSV: {error}'**
  String failedToExportCsv(String error);

  /// Error message for PDF export failure
  ///
  /// In en, this message translates to:
  /// **'Failed to export PDF: {error}'**
  String failedToExportPdf(String error);

  /// Portfolio performance section title
  ///
  /// In en, this message translates to:
  /// **'Portfolio Performance'**
  String get portfolioPerformance;

  /// Average XIRR label
  ///
  /// In en, this message translates to:
  /// **'Avg XIRR'**
  String get avgXirr;

  /// Median XIRR label
  ///
  /// In en, this message translates to:
  /// **'Median XIRR'**
  String get medianXirr;

  /// Profitable investments label
  ///
  /// In en, this message translates to:
  /// **'Profitable'**
  String get profitable;

  /// Loss making investments label
  ///
  /// In en, this message translates to:
  /// **'Loss Making'**
  String get lossMaking;

  /// Total actions label
  ///
  /// In en, this message translates to:
  /// **'Total Actions'**
  String get totalActions;

  /// Urgent actions label
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get urgent;

  /// Overdue actions label
  ///
  /// In en, this message translates to:
  /// **'Overdue Actions'**
  String get overdueActions;

  /// Critical actions section title
  ///
  /// In en, this message translates to:
  /// **'⚠️ Critical Actions'**
  String get criticalActions;

  /// High priority section title
  ///
  /// In en, this message translates to:
  /// **'🔴 High Priority'**
  String get highPriority;

  /// Goals overview section title
  ///
  /// In en, this message translates to:
  /// **'Goals Overview'**
  String get goalsOverview;

  /// Total goals label
  ///
  /// In en, this message translates to:
  /// **'Total Goals'**
  String get totalGoals;

  /// Average progress label
  ///
  /// In en, this message translates to:
  /// **'Avg Progress'**
  String get avgProgress;

  /// Total invested label
  ///
  /// In en, this message translates to:
  /// **'Total Invested'**
  String get totalInvested;

  /// Total returns label
  ///
  /// In en, this message translates to:
  /// **'Total Returns'**
  String get totalReturns;

  /// Weekly summary screen title
  ///
  /// In en, this message translates to:
  /// **'Weekly Summary'**
  String get weeklySummaryTitle;

  /// Monthly income report screen title
  ///
  /// In en, this message translates to:
  /// **'Monthly Income Report'**
  String get monthlyIncomeReportTitle;

  /// FY report screen title
  ///
  /// In en, this message translates to:
  /// **'Financial Year Report'**
  String get fyReportTitle;

  /// Performance report screen title
  ///
  /// In en, this message translates to:
  /// **'Performance Report'**
  String get performanceReportTitle;

  /// Goal progress report screen title
  ///
  /// In en, this message translates to:
  /// **'Goal Progress Report'**
  String get goalProgressReportTitle;

  /// Goal progress screen title
  ///
  /// In en, this message translates to:
  /// **'Goal Progress Report'**
  String get goalProgressTitle;

  /// Target amount label
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get targetLabel;

  /// Maturity calendar screen title
  ///
  /// In en, this message translates to:
  /// **'Maturity Calendar'**
  String get maturityCalendarTitle;

  /// Action required screen title
  ///
  /// In en, this message translates to:
  /// **'Action Required'**
  String get actionRequiredTitle;

  /// Portfolio health screen title
  ///
  /// In en, this message translates to:
  /// **'Portfolio Health'**
  String get portfolioHealthTitle;

  /// Total income label
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get totalIncome;

  /// Total fees label
  ///
  /// In en, this message translates to:
  /// **'Total Fees'**
  String get totalFees;

  /// Net cashflow label
  ///
  /// In en, this message translates to:
  /// **'Net Cashflow'**
  String get netCashflow;

  /// Total returned label
  ///
  /// In en, this message translates to:
  /// **'Total Returned'**
  String get totalReturned;

  /// Top performer label
  ///
  /// In en, this message translates to:
  /// **'Top Performer'**
  String get topPerformer;

  /// New investments label
  ///
  /// In en, this message translates to:
  /// **'New Investments'**
  String get newInvestments;

  /// Upcoming maturities label
  ///
  /// In en, this message translates to:
  /// **'Upcoming Maturities'**
  String get upcomingMaturities;

  /// Income breakdown section title
  ///
  /// In en, this message translates to:
  /// **'Income Breakdown'**
  String get incomeBreakdown;

  /// Top income generators section title
  ///
  /// In en, this message translates to:
  /// **'Top Income Generators'**
  String get topIncomeGenerators;

  /// All transactions section title
  ///
  /// In en, this message translates to:
  /// **'All Transactions'**
  String get allTransactions;

  /// XIRR label
  ///
  /// In en, this message translates to:
  /// **'XIRR'**
  String get xirrLabel;

  /// Monthly breakdown section title
  ///
  /// In en, this message translates to:
  /// **'Monthly Breakdown'**
  String get monthlyBreakdown;

  /// Capital gains summary section title
  ///
  /// In en, this message translates to:
  /// **'Capital Gains Summary'**
  String get capitalGainsSummary;

  /// Capital gains section title (without Summary)
  ///
  /// In en, this message translates to:
  /// **'Capital Gains'**
  String get capitalGains;

  /// Invested label for charts
  ///
  /// In en, this message translates to:
  /// **'Invested'**
  String get investedLabel;

  /// Returned label for charts
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get returnedLabel;

  /// Short-term gains label
  ///
  /// In en, this message translates to:
  /// **'Short-term Gains'**
  String get shortTermGains;

  /// Long-term gains label
  ///
  /// In en, this message translates to:
  /// **'Long-term Gains'**
  String get longTermGains;

  /// Top performers by returns section title
  ///
  /// In en, this message translates to:
  /// **'Top Performers (by Returns)'**
  String get topPerformersByReturns;

  /// Top performers by XIRR section title
  ///
  /// In en, this message translates to:
  /// **'Top Performers (by XIRR)'**
  String get topPerformersByXirr;

  /// Top performers section title
  ///
  /// In en, this message translates to:
  /// **'Top Performers'**
  String get topPerformersSection;

  /// Bottom performers section title
  ///
  /// In en, this message translates to:
  /// **'Bottom Performers'**
  String get bottomPerformers;

  /// Recent milestones section title
  ///
  /// In en, this message translates to:
  /// **'Recent Milestones'**
  String get recentMilestones;

  /// On track goals label
  ///
  /// In en, this message translates to:
  /// **'On Track'**
  String get onTrack;

  /// At risk goals label
  ///
  /// In en, this message translates to:
  /// **'At Risk'**
  String get atRisk;

  /// Achieved goals label
  ///
  /// In en, this message translates to:
  /// **'Achieved'**
  String get achieved;

  /// Goals on track section title
  ///
  /// In en, this message translates to:
  /// **'Goals On Track'**
  String get goalsOnTrack;

  /// Goals at risk section title
  ///
  /// In en, this message translates to:
  /// **'Goals At Risk'**
  String get goalsAtRisk;

  /// Maturity overview section title
  ///
  /// In en, this message translates to:
  /// **'Maturity Overview'**
  String get maturityOverview;

  /// Total investments with maturity label
  ///
  /// In en, this message translates to:
  /// **'Total w/ Maturity'**
  String get totalWithMaturity;

  /// Next 30 days label
  ///
  /// In en, this message translates to:
  /// **'Next 30 Days'**
  String get next30Days;

  /// Next 90 days label
  ///
  /// In en, this message translates to:
  /// **'Next 90 Days'**
  String get next90Days;

  /// Upcoming maturities section title
  ///
  /// In en, this message translates to:
  /// **'Upcoming Maturities'**
  String get upcomingMaturitiesSection;

  /// Matures soon label
  ///
  /// In en, this message translates to:
  /// **'Matures Soon'**
  String get maturesSoon;

  /// Next 90 days total label
  ///
  /// In en, this message translates to:
  /// **'Next 90 Days Total'**
  String get next90DaysTotal;

  /// Matures label for maturity date
  ///
  /// In en, this message translates to:
  /// **'Matures'**
  String get maturesLabel;

  /// All clear message when no actions required
  ///
  /// In en, this message translates to:
  /// **'All Clear!'**
  String get allClear;

  /// No actions required message
  ///
  /// In en, this message translates to:
  /// **'No actions required at this time.'**
  String get noActionsRequired;

  /// Urgent actions label
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get urgentActions;

  /// Overdue items label
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueItems;

  /// Matured investments section title
  ///
  /// In en, this message translates to:
  /// **'Matured Investments'**
  String get maturedInvestments;

  /// Missed dividends section title
  ///
  /// In en, this message translates to:
  /// **'Missed Dividends'**
  String get missedDividends;

  /// Missing data section title
  ///
  /// In en, this message translates to:
  /// **'Missing Data'**
  String get missingData;

  /// Overall health score label
  ///
  /// In en, this message translates to:
  /// **'Overall Health Score'**
  String get overallHealthScore;

  /// Health metrics section title
  ///
  /// In en, this message translates to:
  /// **'Health Metrics'**
  String get healthMetrics;

  /// Diversification label
  ///
  /// In en, this message translates to:
  /// **'Diversification'**
  String get diversification;

  /// Performance label
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performanceLabel;

  /// Activity label
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// Types label
  ///
  /// In en, this message translates to:
  /// **'Types'**
  String get typesLabel;

  /// Investments label (lowercase for use in sentences)
  ///
  /// In en, this message translates to:
  /// **'investments'**
  String get investmentsLabel;

  /// Returns quality label
  ///
  /// In en, this message translates to:
  /// **'Returns Quality'**
  String get returnsQuality;

  /// Data completeness label
  ///
  /// In en, this message translates to:
  /// **'Data Completeness'**
  String get dataCompleteness;

  /// Risk level label
  ///
  /// In en, this message translates to:
  /// **'Risk Level'**
  String get riskLevel;

  /// Recommendations section title
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendationsSection;

  /// By type label
  ///
  /// In en, this message translates to:
  /// **'By Type'**
  String get byType;

  /// By status label
  ///
  /// In en, this message translates to:
  /// **'By Status'**
  String get byStatus;

  /// Summary section title
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// Tooltip explaining XIRR metric
  ///
  /// In en, this message translates to:
  /// **'Extended Internal Rate of Return - Industry standard for calculating returns with multiple transactions at different times. Accounts for when you invested and withdrew money.'**
  String get xirrTooltip;

  /// Tooltip explaining capital gains
  ///
  /// In en, this message translates to:
  /// **'Profit from selling investments. Short-term (<1 year) gains are taxed higher than long-term (>1 year) gains in India.'**
  String get capitalGainsTooltip;

  /// Tooltip explaining net cashflow
  ///
  /// In en, this message translates to:
  /// **'Total money in (dividends, interest) minus money out (investments, withdrawals) for the period. Positive = earning, Negative = investing.'**
  String get netCashflowTooltip;

  /// Tooltip explaining diversification score
  ///
  /// In en, this message translates to:
  /// **'How spread out your investments are across types and platforms. Higher diversification = lower risk.'**
  String get diversificationTooltip;

  /// Tooltip explaining liquidity score
  ///
  /// In en, this message translates to:
  /// **'Percentage of your portfolio maturing in next 90 days. Ideal: 10-30%. Too high = reinvestment work, Too low = illiquid.'**
  String get liquidityTooltip;

  /// Tooltip explaining goal alignment score
  ///
  /// In en, this message translates to:
  /// **'Percentage of your financial goals that are on-track based on current progress. Higher = better goal achievement.'**
  String get goalAlignmentTooltip;

  /// Tooltip explaining action readiness score
  ///
  /// In en, this message translates to:
  /// **'Measures overdue renewals and stale investments. Lower score means you have pending actions to take.'**
  String get actionReadinessTooltip;

  /// Section title for investments maturing in next 30 days
  ///
  /// In en, this message translates to:
  /// **'⏰ Maturing in Next 30 Days'**
  String get maturingNext30Days;

  /// Section title for investments maturing in 31-90 days
  ///
  /// In en, this message translates to:
  /// **'📅 Maturing in 31-90 Days'**
  String get maturing31to90Days;

  /// Section title for investments maturing beyond 90 days
  ///
  /// In en, this message translates to:
  /// **'🗓️ Maturing Beyond 90 Days'**
  String get maturingBeyond90Days;

  /// Label for days remaining until maturity
  ///
  /// In en, this message translates to:
  /// **'{days} days remaining'**
  String daysRemaining(int days);

  /// Section title for bottom performing investments
  ///
  /// In en, this message translates to:
  /// **'📉 Bottom Performers'**
  String get bottomPerformersSection;

  /// Section title for recent investment milestones
  ///
  /// In en, this message translates to:
  /// **'🎯 Recent Milestones'**
  String get recentMilestonesSection;

  /// Section title for achieved goals
  ///
  /// In en, this message translates to:
  /// **'🎉 Achieved Goals'**
  String get achievedGoalsSection;

  /// Section title for high priority action items
  ///
  /// In en, this message translates to:
  /// **'🔴 High Priority'**
  String get highPrioritySection;

  /// Section title for medium priority action items
  ///
  /// In en, this message translates to:
  /// **'🟡 Medium Priority'**
  String get mediumPrioritySection;

  /// Section title for low priority action items
  ///
  /// In en, this message translates to:
  /// **'🔵 Low Priority'**
  String get lowPrioritySection;

  /// Button label for archiving a goal
  ///
  /// In en, this message translates to:
  /// **'Archive Goal'**
  String get archiveGoal;

  /// Button label for unarchiving a goal
  ///
  /// In en, this message translates to:
  /// **'Unarchive Goal'**
  String get unarchiveGoal;

  /// Alert title when signing in with an existing Google account
  ///
  /// In en, this message translates to:
  /// **'Google Account Already Exists'**
  String get googleAccountExists;

  /// Message explaining the account already exists
  ///
  /// In en, this message translates to:
  /// **'This Google account is already registered.'**
  String get accountAlreadyRegistered;

  /// Explanation of the backup process before signing in
  ///
  /// In en, this message translates to:
  /// **'Your guest data will be backed up as a ZIP file. After signing in, you can import it to merge with existing data.'**
  String get guestDataBackupMessage;

  /// Button label to backup data and sign in
  ///
  /// In en, this message translates to:
  /// **'Backup & Sign In'**
  String get backupAndSignIn;

  /// Alert title when backup is successfully created
  ///
  /// In en, this message translates to:
  /// **'Backup Created'**
  String get backupCreated;

  /// Success message after creating backup
  ///
  /// In en, this message translates to:
  /// **'Your guest data has been backed up.'**
  String get guestDataBackedUp;

  /// Shows the file path where backup was saved
  ///
  /// In en, this message translates to:
  /// **'Location: {path}'**
  String backupLocation(String path);

  /// Asks user if they want to import the backup immediately
  ///
  /// In en, this message translates to:
  /// **'Would you like to import it now?'**
  String get importNowQuestion;

  /// Button label to import backup immediately
  ///
  /// In en, this message translates to:
  /// **'Import Now'**
  String get importNow;

  /// Error message when backup fails
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String backupFailed(String error);

  /// PDF report section header for daily cashflows
  ///
  /// In en, this message translates to:
  /// **'Daily Cashflows'**
  String get reportPdfDailyCashflows;

  /// PDF table column header for date
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get reportPdfTableHeaderDate;

  /// PDF table column header for inflow
  ///
  /// In en, this message translates to:
  /// **'Inflow'**
  String get reportPdfTableHeaderInflow;

  /// PDF table column header for outflow
  ///
  /// In en, this message translates to:
  /// **'Outflow'**
  String get reportPdfTableHeaderOutflow;

  /// PDF table column header for net amount
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get reportPdfTableHeaderNet;

  /// Shows maturity date with label
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String maturesOnDate(String date);

  /// Shows due date with label
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String dueOnDate(String date);

  /// Label for overdue items
  ///
  /// In en, this message translates to:
  /// **'OVERDUE'**
  String get overdue;

  /// Shows days in short format
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String daysShort(int days);

  /// PDF report label for total invested amount
  ///
  /// In en, this message translates to:
  /// **'Total Invested'**
  String get reportPdfTotalInvested;

  /// PDF report label for total returned amount
  ///
  /// In en, this message translates to:
  /// **'Total Returned'**
  String get reportPdfTotalReturned;

  /// PDF report label for net position
  ///
  /// In en, this message translates to:
  /// **'Net Position'**
  String get reportPdfNetPosition;

  /// PDF report label for new investments count
  ///
  /// In en, this message translates to:
  /// **'New Investments'**
  String get reportPdfNewInvestments;

  /// PDF report label for total income
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get reportPdfTotalIncome;

  /// PDF report label for transactions count
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get reportPdfTransactions;

  /// PDF report label for XIRR percentage
  ///
  /// In en, this message translates to:
  /// **'XIRR'**
  String get reportPdfXirr;

  /// PDF report label for portfolio health score
  ///
  /// In en, this message translates to:
  /// **'Health Score'**
  String get reportPdfHealthScore;

  /// PDF report label for status
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get reportPdfStatus;

  /// PDF report section header for income breakdown by type
  ///
  /// In en, this message translates to:
  /// **'Income by Type'**
  String get reportPdfIncomeByType;

  /// PDF report section header for monthly data breakdown
  ///
  /// In en, this message translates to:
  /// **'Monthly Breakdown'**
  String get reportPdfMonthlyBreakdown;

  /// PDF report section header for top performing investments
  ///
  /// In en, this message translates to:
  /// **'Top Performers'**
  String get reportPdfTopPerformers;

  /// PDF report section header for bottom performing investments
  ///
  /// In en, this message translates to:
  /// **'Bottom Performers'**
  String get reportPdfBottomPerformers;

  /// PDF report section header for goals on track
  ///
  /// In en, this message translates to:
  /// **'On-Track Goals'**
  String get reportPdfOnTrackGoals;

  /// PDF report section header for goals at risk
  ///
  /// In en, this message translates to:
  /// **'At-Risk Goals'**
  String get reportPdfAtRiskGoals;

  /// PDF report section header for upcoming investment maturities
  ///
  /// In en, this message translates to:
  /// **'Upcoming Maturities'**
  String get reportPdfUpcomingMaturities;

  /// PDF report section header for idle investments
  ///
  /// In en, this message translates to:
  /// **'Idle Investments'**
  String get reportPdfIdleInvestments;

  /// PDF report section header for diversification analysis
  ///
  /// In en, this message translates to:
  /// **'Diversification'**
  String get reportPdfDiversification;

  /// Empty state message when report has no data
  ///
  /// In en, this message translates to:
  /// **'No data available for this report'**
  String get noDataForReport;

  /// Empty state hint for reports screen
  ///
  /// In en, this message translates to:
  /// **'Start tracking investments to see reports'**
  String get startTrackingToSeeReports;

  /// CTA button text to add first investment
  ///
  /// In en, this message translates to:
  /// **'Add Your First Investment'**
  String get addYourFirstInvestment;

  /// Section title for AI-generated insights
  ///
  /// In en, this message translates to:
  /// **'Smart Insights'**
  String get smartInsights;

  /// Title for DIY report builder
  ///
  /// In en, this message translates to:
  /// **'Report Builder'**
  String get reportBuilder;

  /// Button text to create custom report
  ///
  /// In en, this message translates to:
  /// **'Create Custom Report'**
  String get createCustomReport;

  /// Short button text to create report
  ///
  /// In en, this message translates to:
  /// **'Create Report'**
  String get createReport;

  /// Button to expand historical reports
  ///
  /// In en, this message translates to:
  /// **'View Past Reports'**
  String get viewPastReports;

  /// Section title for items requiring user action
  ///
  /// In en, this message translates to:
  /// **'Needs Attention'**
  String get needsAttention;

  /// Warning message for declining investments
  ///
  /// In en, this message translates to:
  /// **'{count} investments down >10%'**
  String investmentsDown(int count);

  /// Warning for upcoming investment maturity
  ///
  /// In en, this message translates to:
  /// **'₹{amount} maturing in {days} days'**
  String upcomingMaturityWarning(String amount, int days);

  /// Warning for goals not on track
  ///
  /// In en, this message translates to:
  /// **'{count} goals behind schedule'**
  String goalsBehindSchedule(int count);

  /// Label for weekly investment summary
  ///
  /// In en, this message translates to:
  /// **'Net invested this week'**
  String get netInvestedThisWeek;

  /// Label for monthly investment summary
  ///
  /// In en, this message translates to:
  /// **'Net invested this month'**
  String get netInvestedThisMonth;

  /// Label for weekly returns
  ///
  /// In en, this message translates to:
  /// **'Returns this week'**
  String get returnsThisWeek;

  /// Label for monthly returns
  ///
  /// In en, this message translates to:
  /// **'Returns this month'**
  String get returnsThisMonth;

  /// Label for income received
  ///
  /// In en, this message translates to:
  /// **'Income received'**
  String get incomeReceived;

  /// Number of income sources (plural-aware)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 source} other{{count} sources}}'**
  String sourcesCount(int count);

  /// Year-to-date performance label
  ///
  /// In en, this message translates to:
  /// **'YTD Performance'**
  String get ytdPerformance;

  /// Performance comparison message
  ///
  /// In en, this message translates to:
  /// **'Portfolio up {actual}% vs goal of {target}%'**
  String portfolioUpVsGoal(String actual, String target);

  /// Section title for recently viewed reports
  ///
  /// In en, this message translates to:
  /// **'Recently Viewed'**
  String get recentlyViewed;

  /// Section title for report templates
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get reportTemplates;

  /// Report template name
  ///
  /// In en, this message translates to:
  /// **'Investment Performance'**
  String get investmentPerformance;

  /// Report template name
  ///
  /// In en, this message translates to:
  /// **'Tax Planning'**
  String get taxPlanning;

  /// Report template name
  ///
  /// In en, this message translates to:
  /// **'Cash Flow Analysis'**
  String get cashFlowAnalysis;

  /// Report builder question
  ///
  /// In en, this message translates to:
  /// **'What do you want to analyze?'**
  String get whatToAnalyze;

  /// Report builder section title
  ///
  /// In en, this message translates to:
  /// **'Time Period'**
  String get timePeriod;

  /// Report builder section title
  ///
  /// In en, this message translates to:
  /// **'Filter By (Optional)'**
  String get filterBy;

  /// Button to generate custom report
  ///
  /// In en, this message translates to:
  /// **'Generate Report'**
  String get generateReport;

  /// Option for custom date range
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customDateRange;

  /// Filter label for category
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// Filter label for minimum amount
  ///
  /// In en, this message translates to:
  /// **'Min Amount'**
  String get minAmount;

  /// Dropdown option for all types
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allTypes;

  /// Call-to-action title for FIRE calculator card
  ///
  /// In en, this message translates to:
  /// **'Calculate Your FIRE Number'**
  String get calculateYourFireNumber;

  /// Subtitle for FIRE calculator card explaining the feature
  ///
  /// In en, this message translates to:
  /// **'Set up your financial independence goals'**
  String get setupFinancialIndependenceGoals;

  /// Label for Multiple on Invested Capital metric
  ///
  /// In en, this message translates to:
  /// **'MOIC'**
  String get moicLabel;

  /// Shows duration of investment returns (e.g., 'over 2 years')
  ///
  /// In en, this message translates to:
  /// **'over {duration}'**
  String overDuration(String duration);

  /// Label for cash flows count metric
  ///
  /// In en, this message translates to:
  /// **'Cash Flows'**
  String get cashFlowsLabel;

  /// Title for FIRE progress card showing progress towards financial independence
  ///
  /// In en, this message translates to:
  /// **'FIRE Progress'**
  String get fireProgressTitle;

  /// Step title for selecting report type in builder
  ///
  /// In en, this message translates to:
  /// **'Select Report Type'**
  String get selectReportType;

  /// Step title for selecting date range in builder
  ///
  /// In en, this message translates to:
  /// **'Select Date Range'**
  String get selectDateRange;

  /// Step title for selecting filters in builder
  ///
  /// In en, this message translates to:
  /// **'Select Filters'**
  String get selectFilters;

  /// Instruction text for report type selection
  ///
  /// In en, this message translates to:
  /// **'Choose the type of report you want to generate'**
  String get chooseReportType;

  /// Description of weekly summary report
  ///
  /// In en, this message translates to:
  /// **'View activity and cashflows for the selected week'**
  String get weeklySummaryDesc;

  /// Description of monthly income report
  ///
  /// In en, this message translates to:
  /// **'Track income from investments for the month'**
  String get monthlyIncomeDesc;

  /// Description of FY report
  ///
  /// In en, this message translates to:
  /// **'Comprehensive financial year analysis'**
  String get fyReportDesc;

  /// Description of performance report
  ///
  /// In en, this message translates to:
  /// **'Analyze top and bottom performing investments'**
  String get performanceReportDesc;

  /// Description of goals report
  ///
  /// In en, this message translates to:
  /// **'Track progress towards your financial goals'**
  String get goalsReportDesc;

  /// Description of maturity calendar report
  ///
  /// In en, this message translates to:
  /// **'View upcoming investment maturities'**
  String get maturityCalendarDesc;

  /// Instruction text for date range selection
  ///
  /// In en, this message translates to:
  /// **'Select the time period for your report'**
  String get selectTimeframe;

  /// Date range filter option
  ///
  /// In en, this message translates to:
  /// **'This Quarter'**
  String get thisQuarter;

  /// Date range filter option
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get thisYear;

  /// Date range filter option
  ///
  /// In en, this message translates to:
  /// **'Last 3 Months'**
  String get lastThreeMonths;

  /// Date range filter option
  ///
  /// In en, this message translates to:
  /// **'Last 6 Months'**
  String get lastSixMonths;

  /// Date range filter option
  ///
  /// In en, this message translates to:
  /// **'Last Year'**
  String get lastYear;

  /// Date range filter option
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// Instruction text for filter selection
  ///
  /// In en, this message translates to:
  /// **'Apply optional filters to narrow down your report'**
  String get optionalFilters;

  /// Label for investment filter dropdown
  ///
  /// In en, this message translates to:
  /// **'Filter by Investment'**
  String get filterByInvestment;

  /// Label for goal filter dropdown
  ///
  /// In en, this message translates to:
  /// **'Filter by Goal'**
  String get filterByGoal;

  /// Dropdown option to show all investments
  ///
  /// In en, this message translates to:
  /// **'All Investments'**
  String get allInvestments;

  /// Dropdown option to show all goals
  ///
  /// In en, this message translates to:
  /// **'All Goals'**
  String get allGoals;

  /// Error message when investments fail to load
  ///
  /// In en, this message translates to:
  /// **'Error loading investments'**
  String get errorLoadingInvestments;

  /// Error message when goals fail to load
  ///
  /// In en, this message translates to:
  /// **'Error loading goals'**
  String get errorLoadingGoals;

  /// Message when selected report type doesn't support filters
  ///
  /// In en, this message translates to:
  /// **'No filters available for this report type'**
  String get noFiltersNeeded;

  /// Description when no filters are needed
  ///
  /// In en, this message translates to:
  /// **'This report does not require any additional filters. Proceed to generate the report.'**
  String get noFiltersNeededDesc;

  /// Validation message when no report type is selected
  ///
  /// In en, this message translates to:
  /// **'Please select a report type to continue'**
  String get pleaseSelectReportType;

  /// Button text to continue to next step in wizard
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueStep;

  /// Button text to go back to previous step
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Title for upcoming maturity insight card
  ///
  /// In en, this message translates to:
  /// **'Upcoming Maturity'**
  String get upcomingMaturityInsight;

  /// Description for upcoming maturity insight
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 investment} other{{count} investments}} maturing in next 30 days'**
  String upcomingMaturityDescription(int count);

  /// Title for monthly income insight card
  ///
  /// In en, this message translates to:
  /// **'Monthly Income'**
  String get monthlyIncomeInsight;

  /// Description for monthly income insight
  ///
  /// In en, this message translates to:
  /// **'{amount} in passive income this month'**
  String monthlyIncomeDescription(String amount);

  /// Title for goal progress insight card
  ///
  /// In en, this message translates to:
  /// **'Goal Progress'**
  String get goalProgressInsight;

  /// Description for goal progress insight
  ///
  /// In en, this message translates to:
  /// **'{goalName} is {percent}% complete'**
  String goalProgressDescription(String goalName, int percent);

  /// Title for top performer insight card
  ///
  /// In en, this message translates to:
  /// **'Top Performer'**
  String get topPerformerInsight;

  /// Description for top performer insight
  ///
  /// In en, this message translates to:
  /// **'{investmentName} returned {returnValue}%'**
  String topPerformerDescription(String investmentName, String returnValue);

  /// Notification title for idle investment review
  ///
  /// In en, this message translates to:
  /// **'💤 Investment Review Needed'**
  String get idleInvestmentReviewTitle;

  /// Notification body for idle investment with activity
  ///
  /// In en, this message translates to:
  /// **'{investmentName} has had no activity for {daysSinceActivity} days. Review this investment?'**
  String idleInvestmentReviewBody(String investmentName, int daysSinceActivity);

  /// Notification body for idle investment without activity
  ///
  /// In en, this message translates to:
  /// **'{investmentName} has no recorded activity. Consider adding cash flows.'**
  String idleInvestmentNoActivityBody(String investmentName);

  /// Subtitle for declining investment insight
  ///
  /// In en, this message translates to:
  /// **'Declining in value'**
  String get decliningInValue;

  /// Export section title in data management
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get dataManagementExportSection;

  /// Import section title in data management
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get dataManagementImportSection;

  /// Danger zone section title in data management
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dataManagementDangerZoneSection;

  /// Export as CSV option subtitle
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet format'**
  String get exportAsCsvSubtitle;

  /// Export as ZIP option title
  ///
  /// In en, this message translates to:
  /// **'Export as ZIP'**
  String get exportAsZip;

  /// Export as ZIP option subtitle
  ///
  /// In en, this message translates to:
  /// **'Full backup with documents'**
  String get exportAsZipSubtitle;

  /// Import from CSV option title
  ///
  /// In en, this message translates to:
  /// **'Import from CSV'**
  String get importFromCsv;

  /// Import from CSV option subtitle
  ///
  /// In en, this message translates to:
  /// **'Add investments from file'**
  String get importFromCsvSubtitle;

  /// Import from ZIP option title
  ///
  /// In en, this message translates to:
  /// **'Import from ZIP'**
  String get importFromZip;

  /// Import from ZIP option subtitle
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get importFromZipSubtitle;

  /// Delete account option subtitle
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all data'**
  String get deleteAccountSubtitle;

  /// Status text shown when deletion is in progress
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deletingStatus;

  /// Warning message for account deletion
  ///
  /// In en, this message translates to:
  /// **'⚠️ Warning: Deleting your account is permanent and cannot be undone. All your data will be lost.'**
  String get dataManagementWarning;

  /// Title for import data handling dialog
  ///
  /// In en, this message translates to:
  /// **'How should we handle existing data?'**
  String get importDataHandlingTitle;

  /// Merge option in import dialog
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get importMergeOption;

  /// Merge option subtitle
  ///
  /// In en, this message translates to:
  /// **'Add new data, skip duplicates'**
  String get importMergeSubtitle;

  /// Replace option in import dialog
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get importReplaceOption;

  /// Replace option subtitle
  ///
  /// In en, this message translates to:
  /// **'Delete existing data first'**
  String get importReplaceSubtitle;

  /// Success message for data export
  ///
  /// In en, this message translates to:
  /// **'Data exported successfully!'**
  String get exportSuccessMessage;

  /// Failure message for data export
  ///
  /// In en, this message translates to:
  /// **'Failed to export data'**
  String get exportFailureMessage;

  /// Success message for data import
  ///
  /// In en, this message translates to:
  /// **'Data imported successfully!'**
  String get importSuccessMessage;

  /// Failure message for data import
  ///
  /// In en, this message translates to:
  /// **'Failed to import data'**
  String get importFailureMessage;

  /// Message when import is cancelled
  ///
  /// In en, this message translates to:
  /// **'Import cancelled'**
  String get importCancelledMessage;

  /// Title for income trend report screen
  ///
  /// In en, this message translates to:
  /// **'Income Trend Report'**
  String get incomeTrendReport;

  /// Header for total income in trend report
  ///
  /// In en, this message translates to:
  /// **'Total Income (Last 12 Months)'**
  String get totalIncomeLast12Months;

  /// Average monthly income label
  ///
  /// In en, this message translates to:
  /// **'Average Monthly'**
  String get averageMonthly;

  /// Section title for growth metrics
  ///
  /// In en, this message translates to:
  /// **'Growth Metrics'**
  String get growthMetrics;

  /// Month-over-month growth label
  ///
  /// In en, this message translates to:
  /// **'Month-over-Month'**
  String get monthOverMonth;

  /// Quarter-over-quarter growth label
  ///
  /// In en, this message translates to:
  /// **'Quarter-over-Quarter'**
  String get quarterOverQuarter;

  /// Chart title for monthly income trend
  ///
  /// In en, this message translates to:
  /// **'Monthly Income Trend'**
  String get monthlyIncomeTrend;

  /// Section title for platform reliability scores
  ///
  /// In en, this message translates to:
  /// **'Platform Reliability'**
  String get platformReliability;

  /// Section title for income diversification analysis
  ///
  /// In en, this message translates to:
  /// **'Income Diversification'**
  String get incomeDiversification;

  /// Section title for auto-generated insights
  ///
  /// In en, this message translates to:
  /// **'Key Insights'**
  String get keyInsights;

  /// Title for income calendar screen
  ///
  /// In en, this message translates to:
  /// **'Income Calendar'**
  String get incomeCalendar;

  /// Error message when income trend report fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load income trend report'**
  String get trendReportLoadFailed;

  /// Retry button label for income trend report
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get trendReportRetry;

  /// Diversification label: HHI score < 0.15
  ///
  /// In en, this message translates to:
  /// **'Excellent diversification'**
  String get diversificationExcellent;

  /// Diversification label: HHI score 0.15-0.30
  ///
  /// In en, this message translates to:
  /// **'Moderate concentration'**
  String get diversificationModerate;

  /// Diversification label: HHI score 0.30-0.50
  ///
  /// In en, this message translates to:
  /// **'High concentration'**
  String get diversificationHigh;

  /// Diversification label: HHI score >= 0.50
  ///
  /// In en, this message translates to:
  /// **'Very high concentration - Risky'**
  String get diversificationRisky;

  /// Section header for overdue payments
  ///
  /// In en, this message translates to:
  /// **'Overdue Payments'**
  String get expectedIncomeOverduePayments;

  /// Section header for upcoming payments
  ///
  /// In en, this message translates to:
  /// **'Upcoming Payments'**
  String get expectedIncomeUpcomingPayments;

  /// Section header for payment history
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get expectedIncomePaymentHistory;

  /// Empty state title when no expected payments
  ///
  /// In en, this message translates to:
  /// **'No Expected Payments'**
  String get expectedIncomeNoPayments;

  /// Empty state subtitle when no expected payments
  ///
  /// In en, this message translates to:
  /// **'This investment has no predicted income payments'**
  String get expectedIncomeNoPaymentsSubtitle;

  /// Error message when expected payments fail to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load expected payments'**
  String get expectedIncomeLoadFailed;

  /// Label for payment reliability score
  ///
  /// In en, this message translates to:
  /// **'Payment Reliability'**
  String get expectedIncomePaymentReliability;

  /// Label for received payment amount
  ///
  /// In en, this message translates to:
  /// **'Received: {amount}'**
  String expectedIncomeReceived(String amount);

  /// Growth trend label: MoM > 5%
  ///
  /// In en, this message translates to:
  /// **'Strong Growth'**
  String get growthTrendStrong;

  /// Growth trend label: MoM 0-5%
  ///
  /// In en, this message translates to:
  /// **'Positive Growth'**
  String get growthTrendPositive;

  /// Growth trend label: MoM -5% to 0%
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get growthTrendStable;

  /// Growth trend label: MoM < -5%
  ///
  /// In en, this message translates to:
  /// **'Declining'**
  String get growthTrendDeclining;

  /// Platform reliability grade: ≥95% on-time
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get platformReliabilityExcellent;

  /// Platform reliability grade: 85-95% on-time
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get platformReliabilityGood;

  /// Platform reliability grade: 70-85% on-time
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get platformReliabilityFair;

  /// Platform reliability grade: <70% on-time
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get platformReliabilityPoor;

  /// Semantic label for maturity date picker button
  ///
  /// In en, this message translates to:
  /// **'Select Maturity Date'**
  String get semanticSelectMaturityDate;

  /// Semantic label for start date picker button
  ///
  /// In en, this message translates to:
  /// **'Select Start Date'**
  String get semanticSelectStartDate;

  /// Value shown when a date field is not set
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// Tooltip for the use biometric authentication button
  ///
  /// In en, this message translates to:
  /// **'Use biometric authentication'**
  String get tooltipUseBiometric;

  /// Tooltip for the clear passcode button
  ///
  /// In en, this message translates to:
  /// **'Clear passcode'**
  String get tooltipClearPasscode;

  /// Tooltip for the delete last digit button
  ///
  /// In en, this message translates to:
  /// **'Delete last digit'**
  String get tooltipDeleteDigit;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
