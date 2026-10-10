# InvTrack 📊

> **Professional Investment Tracking for Alternative Assets**

InvTrack is a mobile-first investment tracking application designed for alternative investments like Fixed Deposits, P2P Lending, Gold, Chit Funds, and other illiquid assets. Unlike traditional portfolio trackers, InvTrack uses a **cash-flow based methodology** to provide professional-grade metrics (XIRR, MOIC, CAGR) for investments that don't have daily market prices.

[![Flutter](https://img.shields.io/badge/Flutter-3.32+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## ✨ Key Features

### 📈 Professional-Grade Metrics
- **XIRR (Extended Internal Rate of Return)** - Annualized returns with exact dates using Newton-Raphson method
- **MOIC (Multiple on Invested Capital)** - Total value / Total invested
- **CAGR (Compound Annual Growth Rate)** - Annualized growth rate
- **Absolute Returns** - Total profit/loss tracking

### 💰 Investment Management
- **Cash Flow Ledger** - Track INVEST, RETURN, INCOME, and FEE transactions
- **Lifecycle Management** - Open → Closed status for investments with end dates
- **Document Attachments** - Attach investment documents (files stay on your device; only metadata syncs to Firestore)
- **Bulk Import** - Import historical data via CSV files

### 🌍 Localization & Internationalization
- **Multi-Currency Support**: Record each investment in its own currency and see totals in your base currency, with automatic locale detection
- **Smart Date Formatting**: Adapts to your region (US, UK, India, Japan, etc.)
- **Locale-Aware Number Formatting**: Indian lakh/crore system, European formatting, etc.
- **Automatic Setup**: Detects your country on first login and configures currency, number format, and date format

See [LOCALIZATION.md](docs/LOCALIZATION.md) for detailed documentation.

### 🎯 Goal Tracking
- **Target Amount Goals** - Track progress towards financial targets
- **Monthly Income Goals** - Plan for passive income streams
- **Smart Projections** - Estimated goal completion dates based on your average monthly progress
- **Progress Milestones** - Celebrate 25%, 50%, 75%, 100% achievements

### 🔥 FIRE Number Calculator
- **Financial Independence Tracking** - Calculate your FIRE number using real (inflation-adjusted) returns
- **Accurate Calculations** - Uses Fisher equation for mathematically correct projections
- **Today's Money** - FIRE numbers shown in today's purchasing power for clarity
- **India-Focused Defaults** - Optimized for Indian investors (INR, 6% inflation, 12% returns)
- **Retirement Planning** - Track progress towards early retirement with realistic goals

### 🔔 Smart Notifications (11 Types)
- Investment milestones (10x, 50x, 100x returns)
- Goal progress alerts (25%, 50%, 75%, 100%)
- Stale investment warnings
- Goal at-risk notifications
- Idle investment alerts
- And more...

### 🔒 Privacy & Security
- **Privacy Mode** - Hide sensitive amounts with one tap
- **Offline-First** - Works offline after first sign-in (Firestore offline persistence); changes sync when you're back online
- **Your Data, Your Control** - Data isolated to your account via Firestore security rules (shared project, per-user access only)
- **Secure PIN Storage** - App-lock PIN hash kept in Keystore-backed FlutterSecureStorage (the offline data cache is not encrypted by the app)
- **Analytics Privacy** - Analytics events are designed to send amount ranges, never exact values (analytics is tied to your user ID; see Tech Stack)
- **Security Practices** - Designed with reference to the OWASP Mobile Application Security Verification Standard (MASVS); not independently audited or certified

### 🌐 Multi-Device Sync
- **Real-time Sync** - Automatic sync across all your devices
- **Conflict Resolution** - Smart handling of offline changes
- **Firebase Firestore** - Cloud database with offline persistence

### 🎨 Beautiful UI/UX
- **Premium Design** - Inspired by modern fintech apps
- **Dark Mode** - Full dark theme support
- **Accessibility** - Screen reader support, designed with reference to WCAG; not independently audited
- **Smooth Animations** - Delightful micro-interactions

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.32 or higher
- Dart 3.0 or higher
- Firebase account (free tier works)
- Android Studio / Xcode (for mobile development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/ravitejakamalapuram/InvTrack.git
   cd InvTrack
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Firebase**
   - Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable Google Sign-In in Authentication
   - Enable Firestore Database
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in the appropriate directories:
     - Android: `android/app/google-services.json`
     - iOS: `ios/Runner/GoogleService-Info.plist`

4. **Configure Firestore Security Rules**
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
       match /appConfig/{document=**} {
         allow read: if request.auth != null;
       }
     }
   }
   ```

5. **Run the app**
   ```bash
   # Run on connected device/emulator
   flutter run

   # Run in release mode
   flutter run --release
   ```

---

## 📱 Screenshots

> Coming soon! Screenshots will be added after App Store submission.

---

## 🏗️ Architecture

InvTrack follows **Clean Architecture** principles with a feature-first folder structure:

```
lib/
├── core/                    # Shared utilities, theme, widgets
│   ├── analytics/          # Firebase Analytics & Crashlytics
│   ├── calculations/       # XIRR, CAGR, MOIC calculations
│   ├── error/              # Error handling & exceptions
│   ├── notifications/      # Smart notification system
│   ├── theme/              # App theme & design tokens
│   └── widgets/            # Reusable UI components
├── features/               # Feature modules
│   ├── auth/              # Google Sign-In authentication
│   ├── investment/        # Investment CRUD & analytics
│   ├── goals/             # Goal tracking & projections
│   ├── fire_number/       # FIRE calculator
│   ├── overview/          # Dashboard & analytics
│   ├── settings/          # App settings & data management
│   └── ...
└── main.dart              # App entry point
```

### Tech Stack
- **Framework**: Flutter 3.32+
- **State Management**: Riverpod
- **Database**: Firebase Firestore (offline-first)
- **Authentication**: Firebase Auth (Google Sign-In)
- **Documents**: stored on-device (metadata in Firestore)
- **Analytics**: Firebase Analytics and Performance Monitoring (tied to user ID, no opt-out yet)
- **Crash Reporting**: Firebase Crashlytics
- **Routing**: GoRouter
- **Charts**: fl_chart
- **Local Storage**: FlutterSecureStorage, SharedPreferences

### Key Design Patterns
- **Repository Pattern** - Abstract data layer
- **Provider Pattern** - Riverpod for state management
- **Offline-First** - Firestore persistence with timeout-based writes
- **Error Hierarchy** - `AppException` base with typed exceptions
- **Clean Architecture** - Domain/Data/Presentation layers

---

## 🧪 Testing

InvTrack has comprehensive test coverage:

```bash
# Run all unit tests
flutter test

# Run integration tests
flutter test integration_test/app_test.dart

# Run specific test suites
flutter test test/features/investment/
flutter test test/core/calculations/

# Run with coverage
flutter test --coverage
```

**Test Stats:**
- ✅ 868+ unit tests passing
- ✅ Comprehensive integration test suite
- ✅ Golden tests for theme & widgets
- ✅ Zero static analysis errors/warnings

---

## 📚 Documentation

- **[Review action plan](docs/review-2026-10/ACTION_PLAN.md)** and **[findings](docs/review-2026-10/FINDINGS.md)** - The current plan of record (October 2026 review)
- **[Financial data model](docs/FINANCIAL_DATA_MODEL.md)** - Ledger, valuation and currency rules
- **[Currency conversion architecture](docs/CURRENCY_CONVERSION_ARCHITECTURE.md)** - How cash flows are converted to your base currency
- **[Localization](docs/LOCALIZATION.md)** and **[currency localization guide](docs/CURRENCY_LOCALIZATION_GUIDE.md)** - Number, date and currency formatting
- **[Notifications](docs/NOTIFICATIONS_KT.md)** - How the notification system works
- **[FIRE Number Guide](docs/fire-number-kt.md)** - FIRE calculator documentation
- **[Bulk Import Guide](docs/BULK_IMPORT_GUIDE.md)** - CSV import instructions
- **[Accessibility](docs/ACCESSIBILITY.md)** - Accessibility guidance
- **[Store listing runbook](docs/UPDATE_STORE_LISTING.md)** and **[CI/CD workflows](.github/workflows/README.md)** - Releasing and the Play listing
- **[Archive](docs/archive/)** - Older status reports, specs and plans. They are kept for history and may not describe the current code.

---

## 🤝 Contributing

Please open an [issue](https://github.com/ravitejakamalapuram/InvTrack/issues) before sending a pull request. All rights are reserved (see [License](#-license)), so code contributions are accepted only after the owner agrees to them.

Development workflow:

1. Create a feature branch (`git checkout -b feature/amazing-feature`)
2. Follow the coding standards in `CLAUDE.md` and `.augment/rules/invtrack_rules.md`
3. Write tests for new features
4. Run static analysis (`flutter analyze --fatal-warnings --no-fatal-infos`) and the tests (`flutter test --exclude-tags=golden`)
5. Commit with a conventional-commit message (`git commit -m 'feat: add amazing feature'`); release notes are generated from these
6. Push the branch and open a Pull Request

### 🤖 AI-Powered Code Review

Pull requests are reviewed with **CodeRabbit** (configured in [`.coderabbit.yaml`](.coderabbit.yaml)). Reviews are not automatic: ask for one by commenting `@coderabbitai review` on the pull request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Flutter Team** - Amazing framework
- **Firebase Team** - Excellent backend services
- **Riverpod** - Elegant state management
- **fl_chart** - Beautiful charts
- **Augment Code** - AI-powered development assistance

---

## 📞 Contact & Support

- **Developer**: Ravi Teja Kamalapuram
- **GitHub**: [@ravitejakamalapuram](https://github.com/ravitejakamalapuram)
- **Issues**: [GitHub Issues](https://github.com/ravitejakamalapuram/InvTrack/issues)
- **Support email**: [support@invtracker.app](mailto:support@invtracker.app)
- **Privacy policy**: https://ravitejakamalapuram.github.io/privacy/invtrack.html
- **Delete your account**: in the app, Settings > Data & Account > Delete Account; on the web (no app needed; sign in with Google, and withdraw the request there if you change your mind): https://ravitejakamalapuram.github.io/delete/invtrack.html; or email the support address from the email you sign in with

---

## 🗺️ Roadmap

### Phase 1: MVP ✅ **COMPLETE**
- [x] Firebase Firestore integration
- [x] Investment CRUD operations
- [x] XIRR/CAGR/MOIC calculations
- [x] Goal tracking
- [x] Smart notifications
- [x] FIRE number calculator
- [x] Multi-device sync

### Phase 2: Intelligence & Automation (Q1 2026)
- [ ] **AI Document Parser** - Google Gemini integration for CSV/PDF parsing
- [ ] Recurring income projections
- [ ] Investment insights & recommendations

### Phase 3: Portfolio Intelligence (Q2 2026)
- [ ] Benchmark comparison (Nifty, S&P 500)
- [ ] Tax reporting
- [ ] What-if scenarios

---

**Made with ❤️ in India**
