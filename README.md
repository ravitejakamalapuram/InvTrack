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
- **Document Attachments** - Store investment documents securely in Firebase Storage
- **Bulk Import** - Import historical data via CSV files

### 🌍 Localization & Internationalization
- **Multi-Currency Support**: 40+ currencies with automatic locale detection
- **Smart Date Formatting**: Adapts to your region (US, UK, India, Japan, etc.)
- **Locale-Aware Number Formatting**: Indian lakh/crore system, European formatting, etc.
- **Automatic Setup**: Detects your country on first login and configures currency, number format, and date format

See [LOCALIZATION.md](docs/LOCALIZATION.md) for detailed documentation.

### 🎯 Goal Tracking
- **Target Amount Goals** - Track progress towards financial targets
- **Monthly Income Goals** - Plan for passive income streams
- **Smart Projections** - AI-powered goal completion predictions
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
- **Offline-First** - Works 100% without internet (Firestore offline persistence)
- **Your Data, Your Control** - Data stored in your own Firebase account
- **Encrypted Storage** - FlutterSecureStorage for sensitive data
- **No PII Logging** - Privacy-compliant analytics (amount ranges only)
- **OWASP MASVS Compliant** - Mobile Application Security Verification Standard

### 🌐 Multi-Device Sync
- **Real-time Sync** - Automatic sync across all your devices
- **Conflict Resolution** - Smart handling of offline changes
- **Firebase Firestore** - Cloud database with offline persistence

### 🎨 Beautiful UI/UX
- **Premium Design** - Inspired by modern fintech apps
- **Dark Mode** - Full dark theme support
- **Accessibility** - WCAG compliant with screen reader support
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
   - Enable Firebase Storage
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
- **Storage**: Firebase Storage (documents)
- **Analytics**: Firebase Analytics
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

- **[Product Roadmap](docs/PRODUCT_ROADMAP.md)** - Feature roadmap and vision
- **[PRD](docs/InvTracker_PRD.md)** - Product Requirements Document
- **[Bulk Import Guide](docs/BULK_IMPORT_GUIDE.md)** - CSV import instructions
- **[FIRE Number Guide](docs/fire-number-kt.md)** - FIRE calculator documentation
- **[TODO](TODO.md)** - Technical debt and improvement backlog

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow the coding standards in `.augment/rules/invtrack_rules.md`
4. Write tests for new features
5. Ensure all tests pass (`flutter test`)
6. Run static analysis (`flutter analyze`)
7. Commit your changes (`git commit -m 'feat: Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

### Code Quality Standards
- Zero analyzer errors/warnings
- All tests passing (≥60% coverage)
- Cyclomatic complexity <15 per 100 lines
- Proper error handling with `AppException` hierarchy
- Accessibility compliance (WCAG)
- Security best practices (OWASP MASVS)
- Clean Architecture layer boundaries enforced

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
