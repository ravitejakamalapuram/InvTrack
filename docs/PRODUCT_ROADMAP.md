# InvTracker — Product Roadmap & Goal Tracker

> **Version 1.0** | Last Updated: 2025-12-25
> **Vision**: "The Mint for Alternative Investments"

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Assessment](#2-current-state-assessment)
3. [Strategic Vision](#3-strategic-vision)
4. [Target Market & User Personas](#4-target-market--user-personas)
5. [Product Roadmap Phases](#5-product-roadmap-phases)
6. [Monetization Strategy](#6-monetization-strategy)
7. [Technical Priorities](#7-technical-priorities)
8. [Go-To-Market Strategy](#8-go-to-market-strategy)
9. [90-Day Execution Plan](#9-90-day-execution-plan)
10. [Success Metrics & KPIs](#10-success-metrics--kpis)
11. [Risk Assessment](#11-risk-assessment)
12. [Goal Tracker](#12-goal-tracker)

---

## 1. Executive Summary

**InvTracker** is a mobile-first application for tracking alternative investments using a cash-flow based methodology. Unlike traditional portfolio trackers that focus on holdings and market values, InvTracker tracks what "went out and came back" — providing professional-grade metrics like XIRR, MOIC, and CAGR for investments that don't have daily market prices.

### The Problem We Solve

| Traditional Trackers | InvTracker |
|---------------------|------------|
| Focus on stocks, mutual funds, ETFs | Focus on P2P, FDs, Real Estate, Private Equity |
| Require daily market prices | Work with irregular cash flows |
| Track units and NAV | Track cash out and cash in |
| Simple % returns | XIRR, MOIC, CAGR calculations |
| Always "open" positions | Clear lifecycle: Open → Closed |

### Market Opportunity

- **Global Alternative Investments Market**: $13 trillion (2024), growing 10% annually
- **India P2P Lending Market**: ₹10,000 crore, 30%+ CAGR
- **HNI Population (India)**: 7.5 lakh individuals with ₹5Cr+ investable assets
- **Gap**: No dedicated app for tracking alternative investments with professional metrics

---

## 2. Current State Assessment

### ✅ MVP Features Complete (Phase 1)

| Feature | Status | Notes |
|---------|--------|-------|
| Firebase Firestore database | ✅ Complete | Offline-first with persistence |
| Google Sign-In authentication | ✅ Complete | Firebase Auth integration |
| Investment CRUD operations | ✅ Complete | Create, Read, Update, Delete |
| Investment lifecycle (Open/Closed) | ✅ Complete | With reopen capability |
| Cash Flow ledger | ✅ Complete | INVEST, RETURN, INCOME, FEE types |
| XIRR calculation | ✅ Complete | Newton-Raphson implementation |
| MOIC calculation | ✅ Complete | Multiple on Invested Capital |
| CAGR calculation | ✅ Complete | Compound Annual Growth Rate |
| Analytics dashboard | ✅ Complete | Hero card, charts, trends |
| Monthly cash flow trend chart | ✅ Complete | Visual bar chart |
| Investment type distribution | ✅ Complete | Pie/bar visualization |
| Year-over-Year comparison | ✅ Complete | YoY net position |
| Recently closed investments | ✅ Complete | Quick access card |
| Real-time multi-device sync | ✅ Complete | Firestore realtime |
| Bulk CSV import | ✅ Complete | With template |
| Dark mode support | ✅ Complete | System + manual toggle |
| Premium/Paywall infrastructure | ✅ Complete | RevenueCat ready |
| Cross-platform support | ✅ Complete | iOS, Android, Web, Desktop |

### 🔧 Technical Foundation

| Component | Technology | Status |
|-----------|------------|--------|
| Framework | Flutter 3.x | ✅ |
| State Management | Riverpod 2.x | ✅ |
| Database | Firebase Firestore | ✅ |
| Authentication | Firebase Auth | ✅ |
| Navigation | GoRouter | ✅ |
| Charts | fl_chart | ✅ |
| Security | Firebase Security Rules | ✅ |
| Offline Support | Firestore Persistence | ✅ |

### ⚠️ Technical Debt to Address

| Item | Priority | Status |
|------|----------|--------|
| Integration tests for critical flows | P1 | [ ] Not Started |
| Architecture documentation | P1 | [ ] Not Started |
| Firebase Analytics integration | P1 | [ ] Not Started |
| Crashlytics integration | P1 | [ ] Not Started |
| Localization infrastructure | P2 | [ ] Not Started |
| Performance monitoring | P2 | [ ] Not Started |
| Structured logging | P2 | [ ] Not Started |

---

## 3. Strategic Vision

### Vision Statement

> "To become the definitive tracking and analytics platform for alternative investments, empowering individuals to understand their true investment returns across all non-traditional asset classes."

### Mission

> "Simplify the complexity of tracking alternative investments by providing intuitive cash-flow based tracking with professional-grade financial metrics."

### Core Principles

1. **Privacy-First**: User data stays in their own Firebase account
2. **Offline-First**: Works 100% without internet
3. **Simple Input, Maximum Insight**: Minimal data entry, powerful analytics
4. **Beautiful Design**: Premium UI/UX inspired by CRED, Mercury
5. **Accuracy**: Professional-grade calculations (XIRR, MOIC, CAGR)

### Competitive Positioning

```
                    HIGH COMPLEXITY
                          │
    ┌─────────────────────┼─────────────────────┐
    │                     │                     │
    │   Bloomberg         │    InvTracker       │
    │   Terminal          │    (Target)         │
    │                     │                     │
LOW ├─────────────────────┼─────────────────────┤ HIGH
ALTERNATIVE               │              ALTERNATIVE
FOCUS                     │                   FOCUS
    │                     │                     │
    │   Robinhood         │    Spreadsheets     │
    │   Zerodha           │    (Current)        │
    │                     │                     │
    └─────────────────────┼─────────────────────┘
                          │
                    LOW COMPLEXITY
```

### Unique Value Propositions

1. **Only app focused on alternative investments** with proper XIRR tracking
2. **Cash-flow methodology** that works for illiquid assets
3. **Lifecycle management** (Open → Closed) for investments with end dates
4. **Multi-device sync** without subscription (Firebase free tier)
5. **AI-powered data entry** (upcoming) - snap a document, auto-extract data

---

## 4. Target Market & User Personas

### Primary Market: India

**Why India First?**
- Massive alternative investment culture (FDs, Gold, Chit Funds, P2P)
- Growing P2P lending market (30%+ CAGR)
- 7.5 lakh+ HNIs actively investing in alternatives
- English-speaking tech-savvy population
- Strong mobile-first behavior

### Secondary Markets (Phase 2)

| Market | Opportunity | Timeline |
|--------|-------------|----------|
| Singapore | HNI hub, strong alternative investment culture | Q3 2026 |
| UAE | Expat population, real estate investments | Q4 2026 |
| US | Indian diaspora, angel investing culture | Q1 2027 |
| UK | Property investments, P2P lending | Q2 2027 |

### User Personas

#### Persona 1: "The Diversified Professional" (Primary)

| Attribute | Details |
|-----------|---------|
| **Name** | Rahul Mehta |
| **Age** | 35-45 |
| **Occupation** | Senior Manager / Business Owner |
| **Income** | ₹30L - ₹1Cr annually |
| **Investable Assets** | ₹50L - ₹5Cr |
| **Investment Mix** | 40% MFs, 30% FDs, 15% P2P, 10% Real Estate, 5% Gold |
| **Pain Points** | • Tracks P2P and FDs in spreadsheets<br>• No idea of true XIRR across investments<br>• Loses track of maturity dates<br>• Can't easily see overall returns |
| **Goals** | • Understand true returns on all investments<br>• Get reminded before maturities<br>• Compare performance across categories |
| **Tech Savvy** | High - uses Zerodha, Groww, multiple P2P apps |
| **Willingness to Pay** | ₹500-1500/month for quality tools |

#### Persona 2: "The Passive Wealth Builder" (Secondary)

| Attribute | Details |
|-----------|---------|
| **Name** | Priya Sharma |
| **Age** | 28-35 |
| **Occupation** | IT Professional |
| **Income** | ₹15L - ₹40L annually |
| **Investable Assets** | ₹10L - ₹50L |
| **Investment Mix** | 60% MFs (SIP), 25% FDs, 10% P2P, 5% Gold |
| **Pain Points** | • Just started alternative investments<br>• Doesn't understand XIRR/IRR<br>• Wants simple tracking without spreadsheets |
| **Goals** | • Easy way to see money in vs money out<br>• Understand if P2P is worth the risk<br>• Build long-term wealth visibility |
| **Tech Savvy** | Medium - uses apps but prefers simplicity |
| **Willingness to Pay** | ₹200-500/month |

#### Persona 3: "The HNI Angel Investor" (Premium)

| Attribute | Details |
|-----------|---------|
| **Name** | Vikram Reddy |
| **Age** | 45-55 |
| **Occupation** | CXO / Entrepreneur / Retired |
| **Income** | ₹1Cr+ annually |
| **Investable Assets** | ₹5Cr+ |
| **Investment Mix** | 20% MFs, 15% FDs, 20% Real Estate, 25% PE/VC, 15% Angel, 5% Others |
| **Pain Points** | • Manages 20+ investments across categories<br>• Needs to track multiple angel deals<br>• Wants professional reporting for CA<br>• Family investments mixed with personal |
| **Goals** | • Professional portfolio overview<br>• Tax-ready reports<br>• Family account management<br>• Share with financial advisor |
| **Tech Savvy** | Medium - delegates to CA/assistant |
| **Willingness to Pay** | ₹2000-5000/month for comprehensive solution |

### Market Size Estimation (India)

| Segment | Population | Target Penetration | Potential Users |
|---------|------------|-------------------|-----------------|
| HNIs (₹5Cr+) | 7,50,000 | 10% | 75,000 |
| Affluent (₹1-5Cr) | 30,00,000 | 5% | 1,50,000 |
| Mass Affluent (₹25L-1Cr) | 1,00,00,000 | 2% | 2,00,000 |
| **Total Addressable Market** | | | **4,25,000** |

At 5% premium conversion and ₹6,000/year ARPU = **₹127 Crore TAM**

---

## 5. Product Roadmap Phases

### Phase 2: Intelligence & Automation (Q1 2026)

**Theme**: Reduce friction in data entry and provide proactive insights

#### Feature 2.1: AI Document Parser (P0 - Critical)

| Attribute | Details |
|-----------|---------|
| **Description** | Upload bank statements, PDFs, Excel files and auto-extract investment data |
| **User Story** | "As a user, I want to upload my P2P platform statement and have the app automatically create investments and cash flows" |
| **Technology** | Google Gemini API for document understanding |
| **Scope** | • PDF text extraction<br>• Excel/CSV parsing<br>• Image OCR for scanned documents<br>• Structured data extraction<br>• User verification before save |
| **Success Metrics** | • 80% extraction accuracy<br>• 50% reduction in manual entry time |
| **Effort** | 4-6 weeks |
| **Dependencies** | Gemini API access, document storage in Firebase Storage |
| **Status** | [ ] Not Started |

**Implementation Details:**
```
User Flow:
1. Tap "Import" → Select "Upload Document"
2. Choose file (PDF, Excel, CSV, Image)
3. AI processes and extracts data
4. Shows preview: "Found 5 investments with 23 cash flows"
5. User reviews/edits each item
6. Confirm → Save to database
```

#### Feature 2.2: Smart Notifications (P1 - High)

| Attribute | Details |
|-----------|---------|
| **Description** | Proactive alerts for maturity dates, expected income, and portfolio events |
| **User Story** | "As a user, I want to be reminded 7 days before my FD matures so I can plan reinvestment" |
| **Technology** | Firebase Cloud Messaging + Cloud Functions |
| **Notification Types** | • Maturity reminders (7d, 3d, 1d before)<br>• Monthly income summary<br>• Investment performance alerts<br>• Milestone celebrations |
| **Success Metrics** | • 60% notification open rate<br>• 30% action rate on reminders |
| **Effort** | 2-3 weeks |
| **Status** | [ ] Not Started |

**Notification Schedule:**
| Type | Trigger | Message Example |
|------|---------|-----------------|
| Maturity Reminder | 7 days before closedAt | "📅 Your HDFC FD (₹5L) matures on Jan 15. Plan your reinvestment!" |
| Expected Income | Based on pattern | "💰 Expected: ₹12,500 income from P2P this month" |
| Monthly Summary | 1st of month | "📊 December: ₹45,000 invested, ₹18,000 returned. Net: -₹27,000" |
| Milestone | Achievement triggers | "🎉 Congratulations! Your portfolio crossed ₹50L invested" |
| Performance Alert | XIRR change > 5% | "📈 Your overall XIRR improved to 14.2% (+2.1% this month)" |

#### Feature 2.3: Recurring Income Projections (P1 - High)

| Attribute | Details |
|-----------|---------|
| **Description** | Forecast future cash flows based on historical patterns and known schedules |
| **User Story** | "As a user, I want to see projected income for the next 12 months" |
| **Features** | • Pattern recognition for recurring income<br>• Manual recurring setup<br>• Calendar view of expected flows<br>• Cash flow forecast chart |
| **Success Metrics** | • 85% forecast accuracy for recurring items |
| **Effort** | 2-3 weeks |
| **Status** | [ ] Not Started |

#### Feature 2.4: Investment Insights & Suggestions (P2 - Medium)

| Attribute | Details |
|-----------|---------|
| **Description** | AI-powered insights comparing investment performance |
| **Examples** | • "Your P2P returns (18% XIRR) outperform your FDs (7%) by 11%"<br>• "Consider rebalancing: 60% of your portfolio is in low-yield FDs"<br>• "Your real estate investment has the highest MOIC (2.3x)" |
| **Technology** | Local calculation + optional Gemini for natural language |
| **Effort** | 2 weeks |
| **Status** | [ ] Not Started |

### Phase 2 Summary

| Feature | Priority | Effort | Status | Target Date |
|---------|----------|--------|--------|-------------|
| AI Document Parser | P0 | 6 weeks | [ ] | Feb 2026 |
| Smart Notifications | P1 | 3 weeks | [ ] | Mar 2026 |
| Recurring Projections | P1 | 3 weeks | [ ] | Mar 2026 |
| Investment Insights | P2 | 2 weeks | [ ] | Apr 2026 |

---

### Phase 3: Portfolio Intelligence (Q2 2026)

**Theme**: Add professional-grade features for serious investors

#### Feature 3.1: Multi-Currency Support (P0 - Critical)

| Attribute | Details |
|-----------|---------|
| **Description** | Track investments in multiple currencies with conversion |
| **User Story** | "As an NRI, I want to track my India FDs in INR and US investments in USD, with a combined view" |
| **Currencies** | INR, USD, EUR, GBP, SGD, AED, CAD, AUD |
| **Features** | • Per-investment currency setting<br>• Real-time exchange rates (or manual)<br>• Consolidated view in base currency<br>• Currency-wise breakdown |
| **API** | Exchange rates API (free tier available) |
| **Effort** | 3-4 weeks |
| **Status** | [ ] Not Started |

#### Feature 3.2: Benchmark Comparison (P1 - High)

| Attribute | Details |
|-----------|---------|
| **Description** | Compare portfolio XIRR against market benchmarks |
| **Benchmarks** | • Nifty 50 (India equity)<br>• S&P 500 (US equity)<br>• FD rates (SBI/HDFC)<br>• Inflation (CPI)<br>• Gold prices |
| **Features** | • Time-period comparison (1Y, 3Y, 5Y, All)<br>• Visual chart overlay<br>• "You beat Nifty by 3.2%" messaging |
| **Data Source** | Free financial APIs + cached data |
| **Effort** | 2-3 weeks |
| **Status** | [ ] Not Started |

#### Feature 3.3: Tax Reporting (P1 - High)

| Attribute | Details |
|-----------|---------|
| **Description** | Generate tax-ready statements for CA/filing |
| **Reports** | • Financial year summary<br>• Interest income breakdown<br>• Capital gains summary<br>• TDS deducted summary |
| **Export Formats** | PDF, Excel, CSV |
| **Effort** | 3 weeks |
| **Status** | [ ] Not Started |

#### Feature 3.4: Goal Tracking (P2 - Medium)

| Attribute | Details |
|-----------|---------|
| **Description** | Set financial goals and track progress |
| **Examples** | • "Retirement Fund: ₹2Cr goal, currently ₹85L (42.5%)"<br>• "Child Education: ₹50L by 2030" |
| **Features** | • Link investments to goals<br>• Progress visualization<br>• Projected achievement date |
| **Effort** | 2 weeks |
| **Status** | [ ] Not Started |

#### Feature 3.5: What-If Scenarios (P2 - Medium)

| Attribute | Details |
|-----------|---------|
| **Description** | Simulate impact of investment decisions |
| **Examples** | • "If I add ₹5L to FDs, my overall XIRR becomes..."<br>• "If my P2P defaults 10%, my portfolio impact is..." |
| **Features** | • Scenario builder<br>• Impact visualization<br>• Save/compare scenarios |
| **Effort** | 2 weeks |
| **Status** | [ ] Not Started |

### Phase 3 Summary

| Feature | Priority | Effort | Status | Target Date |
|---------|----------|--------|--------|-------------|
| Multi-Currency Support | P0 | 4 weeks | [ ] | May 2026 |
| Benchmark Comparison | P1 | 3 weeks | [ ] | May 2026 |
| Tax Reporting | P1 | 3 weeks | [ ] | Jun 2026 |
| Goal Tracking | P2 | 2 weeks | [ ] | Jun 2026 |
| What-If Scenarios | P2 | 2 weeks | [ ] | Jul 2026 |

---

### Phase 4: Connectivity (Q3 2026)

**Theme**: Automate data collection and enable sharing

#### Feature 4.1: Bank Account Linking (P0 - Critical)

| Attribute | Details |
|-----------|---------|
| **Description** | Auto-import transactions from bank accounts |
| **Technology** | Account Aggregator (India) / Plaid (US/UK) |
| **User Story** | "As a user, I want my bank transactions to auto-sync so I don't have to manually enter" |
| **Flow** | 1. Link bank via AA<br>2. Pull transaction history<br>3. AI categorizes as investments<br>4. User confirms |
| **Compliance** | RBI Account Aggregator framework |
| **Effort** | 6-8 weeks |
| **Status** | [ ] Not Started |

#### Feature 4.2: Broker Integration (P1 - High)

| Attribute | Details |
|-----------|---------|
| **Description** | Connect with brokers to import mutual fund/stock data |
| **Partners** | Zerodha (Kite Connect), Groww, ICICIDirect, CAMS/KFintech |
| **Data Import** | • Mutual fund holdings<br>• Stock positions<br>• Transaction history<br>• Dividend income |
| **Effort** | 4-6 weeks per integration |
| **Status** | [ ] Not Started |

#### Feature 4.3: Family Accounts (P1 - High)

| Attribute | Details |
|-----------|---------|
| **Description** | Track family members' investments in single view |
| **Features** | • Add family members (up to 5)<br>• Per-member portfolio view<br>• Combined family dashboard<br>• Permission controls |
| **Use Cases** | • Track spouse's investments<br>• Monitor parents' FDs<br>• Children's education fund |
| **Effort** | 4 weeks |
| **Status** | [ ] Not Started |

#### Feature 4.4: Advisor Sharing (P2 - Medium)

| Attribute | Details |
|-----------|---------|
| **Description** | Share read-only access with CA or financial advisor |
| **Features** | • Generate share link<br>• Time-limited access<br>• Selective data sharing<br>• Activity audit log |
| **Use Cases** | • CA needs tax data<br>• Financial planner review<br>• Family office reporting |
| **Effort** | 3 weeks |
| **Status** | [ ] Not Started |

### Phase 4 Summary

| Feature | Priority | Effort | Status | Target Date |
|---------|----------|--------|--------|-------------|
| Bank Account Linking | P0 | 8 weeks | [ ] | Sep 2026 |
| Broker Integration | P1 | 6 weeks | [ ] | Oct 2026 |
| Family Accounts | P1 | 4 weeks | [ ] | Oct 2026 |
| Advisor Sharing | P2 | 3 weeks | [ ] | Nov 2026 |

---

### Phase 5: Community & Advanced Monetization (Q4 2026)

**Theme**: Build network effects and premium revenue streams

#### Feature 5.1: Premium Tier Enhancement (P0 - Critical)

| Attribute | Details |
|-----------|---------|
| **Description** | Full premium paywall with RevenueCat |
| **Tiers** | Free, Pro, Family, Advisor (see Section 6) |
| **Features** | • In-app purchase flow<br>• Feature gating<br>• Trial periods<br>• Upgrade prompts |
| **Effort** | 3 weeks |
| **Status** | [ ] Not Started |

#### Feature 5.2: Anonymous Benchmarks (P1 - High)

| Attribute | Details |
|-----------|---------|
| **Description** | Compare performance against anonymized user base |
| **Examples** | • "Your P2P returns are in the top 20% of users"<br>• "Average XIRR for FDs is 6.8% - you're at 7.2%" |
| **Privacy** | • Fully anonymized aggregation<br>• Opt-in only<br>• No individual data sharing |
| **Effort** | 3 weeks |
| **Status** | [ ] Not Started |

#### Feature 5.3: Investment Marketplace (P2 - Medium)

| Attribute | Details |
|-----------|---------|
| **Description** | Curated directory of investment platforms |
| **Content** | • P2P platforms (LendenClub, Faircent, etc.)<br>• FD comparison<br>• Bond platforms<br>• Real estate fractional |
| **Revenue Model** | Referral commission / Lead generation |
| **Effort** | 4 weeks |
| **Status** | [ ] Not Started |

#### Feature 5.4: Advisory Connect (P2 - Medium)

| Attribute | Details |
|-----------|---------|
| **Description** | Connect users with verified financial advisors |
| **Features** | • Advisor directory<br>• Book consultation<br>• Share portfolio |
| **Revenue Model** | Lead generation fee to advisors |
| **Effort** | 4 weeks |
| **Status** | [ ] Not Started |

### Phase 5 Summary

| Feature | Priority | Effort | Status | Target Date |
|---------|----------|--------|--------|-------------|
| Premium Tier Enhancement | P0 | 3 weeks | [ ] | Nov 2026 |
| Anonymous Benchmarks | P1 | 3 weeks | [ ] | Nov 2026 |
| Investment Marketplace | P2 | 4 weeks | [ ] | Dec 2026 |
| Advisory Connect | P2 | 4 weeks | [ ] | Dec 2026 |

---

## 6. Monetization Strategy

### Pricing Tiers

#### Free Tier

| Feature | Limit |
|---------|-------|
| Active Investments | 5 |
| Cash Flows per Investment | 20 |
| Data Retention | 1 year |
| Basic Analytics | ✅ |
| XIRR/MOIC Calculations | ✅ |
| Multi-device Sync | ✅ |
| Dark Mode | ✅ |
| CSV Import | ❌ |
| AI Document Parser | ❌ |
| Export Reports | ❌ |
| Notifications | ❌ |
| Multi-Currency | ❌ |

#### Pro Tier - ₹799/month or ₹5,999/year ($9.99/month or $79/year)

| Feature | Limit |
|---------|-------|
| Active Investments | Unlimited |
| Cash Flows per Investment | Unlimited |
| Data Retention | Unlimited |
| All Free Features | ✅ |
| CSV/Excel Import | ✅ |
| AI Document Parser | 10 docs/month |
| Export Reports (PDF/CSV) | ✅ |
| Smart Notifications | ✅ |
| Multi-Currency | ✅ |
| Benchmark Comparison | ✅ |
| Tax Reports | ✅ |
| Priority Support | ✅ |

#### Family Tier - ₹1,499/month or ₹11,999/year ($19.99/month or $149/year)

| Feature | Limit |
|---------|-------|
| All Pro Features | ✅ |
| Family Members | Up to 5 |
| Combined Dashboard | ✅ |
| AI Document Parser | 30 docs/month |
| Advisor Sharing | ✅ |
| Goal Tracking | ✅ |
| Bank Linking | Coming Soon |

#### Advisor Tier - ₹3,999/month or ₹35,999/year ($49.99/month or $399/year)

| Feature | Limit |
|---------|-------|
| All Family Features | ✅ |
| Client Management | Up to 25 clients |
| Branded Reports | ✅ |
| Bulk Operations | ✅ |
| API Access | ✅ |
| White-label Option | Add-on |
| Dedicated Support | ✅ |

### Revenue Projections

#### Year 1 (2026) - Launch & Initial Growth

| Metric | Q1 | Q2 | Q3 | Q4 | Total |
|--------|----|----|----|----|-------|
| Total Users | 2,000 | 5,000 | 10,000 | 20,000 | - |
| Free Users | 1,900 | 4,700 | 9,300 | 18,500 | - |
| Pro Subscribers | 80 | 240 | 560 | 1,200 | - |
| Family Subscribers | 15 | 45 | 105 | 225 | - |
| Advisor Subscribers | 5 | 15 | 35 | 75 | - |
| MRR (₹) | 95K | 285K | 665K | 1.4M | - |
| ARR (₹) | - | - | - | - | **₹1.7 Cr** |

#### Year 2 (2027) - Scale

| Metric | Target |
|--------|--------|
| Total Users | 100,000 |
| Pro Subscribers | 6,000 |
| Family Subscribers | 1,200 |
| Advisor Subscribers | 300 |
| ARR | **₹8 Cr** |

#### Year 3 (2028) - Expansion

| Metric | Target |
|--------|--------|
| Total Users | 500,000 |
| Pro Subscribers | 30,000 |
| Family Subscribers | 6,000 |
| Advisor Subscribers | 1,000 |
| ARR | **₹40 Cr** |

### Alternative Revenue Streams

| Stream | Description | Potential |
|--------|-------------|-----------|
| Referral Commission | P2P platforms, FD providers | ₹500-2000 per lead |
| Advisory Leads | Connect users to advisors | ₹1000-5000 per lead |
| Data Insights | Anonymized market research | Enterprise contracts |
| White-label | License to wealth managers | ₹1L+/year per client |

---

## 7. Technical Priorities

### Architecture Overview

The application follows **Clean Architecture** with a **feature-first folder structure**:

```
lib/
├── app/                    # App entry point
├── core/                   # Shared infrastructure
│   ├── analytics/          # Firebase Analytics + Crashlytics
│   ├── calculations/       # XIRR/CAGR solvers (Newton-Raphson)
│   ├── di/                 # Dependency injection (Riverpod providers)
│   ├── error/              # Exception hierarchy (AppException)
│   ├── notifications/      # Local notifications
│   ├── router/             # GoRouter configuration
│   ├── theme/              # Design system (colors, spacing)
│   └── widgets/            # Reusable UI components
└── features/               # Feature modules
    ├── auth/               # Firebase Authentication
    ├── bulk_import/        # CSV/Excel import
    ├── investment/         # Core investment feature
    │   ├── data/           # Firestore repository implementation
    │   ├── domain/         # Entities, repository interfaces
    │   └── presentation/   # Screens, widgets, providers
    ├── overview/           # Dashboard analytics
    ├── settings/           # App settings
    └── security/           # Passcode/biometrics
```

#### Architecture Scorecard

| Area | Score | Notes |
|------|-------|-------|
| Folder Structure | ⭐⭐⭐⭐⭐ | Excellent feature-first organization |
| State Management | ⭐⭐⭐⭐⭐ | Riverpod used correctly with proper separation |
| Data Layer | ⭐⭐⭐⭐ | Good abstraction, DTOs recommended for Phase 2 |
| Error Handling | ⭐⭐⭐⭐⭐ | Well-designed exception hierarchy |
| Testing | ⭐⭐⭐ | Good coverage, expand widget/integration tests |
| Performance | ⭐⭐⭐⭐ | Recently optimized with lazy loading |
| Scalability | ⭐⭐⭐⭐ | Good patterns for Phase 2/3 features |

#### Key Architectural Patterns

1. **Repository Pattern** - Abstract interface in domain, Firestore implementation in data
2. **Riverpod Providers** - `StreamProvider` for reactive data, `StateNotifier` for mutations
3. **Offline-First** - Firestore persistence with timeout-based write handling
4. **Error Hierarchy** - `AppException` base with `AuthException`, `DataException`, `ValidationException`

### Immediate Technical Debt (Before Launch)

| Priority | Task | Description | Effort | Status |
|----------|------|-------------|--------|--------|
| P0 | Integration Tests | Critical user flow tests | 1 week | [ ] |
| P0 | Firebase Analytics | Track user behavior | 2 days | [x] Complete |
| P0 | Crashlytics | Crash reporting | 1 day | [x] Complete |
| P0 | App Store Setup | iOS App Store + Google Play | 1 week | [ ] |
| P1 | Performance Monitoring | Firebase Performance | 2 days | [ ] |
| P1 | Structured Logging | Replace debugPrint | 2 days | [ ] |
| P2 | Architecture Docs | Document architecture | 1 day | [x] Complete |

### Integration Test Coverage Required

| Flow | Priority | Status |
|------|----------|--------|
| User sign-in with Google | P0 | [ ] |
| User sign-out | P0 | [ ] |
| Create investment with initial cash flow | P0 | [ ] |
| Add cash flow to existing investment | P0 | [ ] |
| Edit cash flow | P1 | [ ] |
| Delete cash flow | P1 | [ ] |
| Close investment | P0 | [ ] |
| Reopen investment | P1 | [ ] |
| Bulk import from CSV | P0 | [ ] |
| Investment merge | P1 | [ ] |
| Settings changes persist | P2 | [ ] |
| Offline mode works | P1 | [ ] |

### Analytics Events to Track

| Event | Properties | Purpose |
|-------|------------|---------|
| `app_open` | `platform`, `version` | DAU/MAU |
| `sign_in` | `method` | Auth funnel |
| `investment_created` | `type`, `has_notes` | Feature usage |
| `cashflow_added` | `type`, `amount_range` | Core action |
| `csv_imported` | `row_count`, `success` | Bulk usage |
| `screen_view` | `screen_name`, `duration` | Engagement |
| `premium_prompt_shown` | `trigger`, `tier` | Monetization |
| `premium_purchased` | `tier`, `price` | Revenue |
| `export_generated` | `format`, `type` | Premium usage |
| `error_occurred` | `type`, `screen` | Quality |

### Infrastructure Roadmap

| Phase | Infrastructure | Timeline |
|-------|---------------|----------|
| Launch | Firebase (Auth, Firestore, Analytics, Crashlytics) | Now |
| Phase 2 | Firebase Storage (documents), Cloud Functions | Q1 2026 |
| Phase 3 | Exchange Rate API, External data caching | Q2 2026 |
| Phase 4 | Account Aggregator integration, Plaid | Q3 2026 |
| Scale | Consider backend service for heavy computation | Q4 2026 |

---

## 8. Go-To-Market Strategy

### Phase 1: India Launch (Q1 2026)

#### Target Channels

| Channel | Strategy | Budget | Expected Users |
|---------|----------|--------|----------------|
| **Twitter/X FinTwit** | Organic content + influencer partnerships | ₹50K/month | 2,000 |
| **LinkedIn** | Thought leadership on alternative investments | ₹20K/month | 500 |
| **YouTube** | Partner with personal finance creators | ₹1L one-time | 3,000 |
| **Reddit** | r/IndiaInvestments, r/PersonalFinanceIndia | Organic | 1,000 |
| **Product Hunt** | Launch campaign | Free | 500 |
| **App Store ASO** | Keywords, screenshots, description | Ongoing | 2,000 |

#### Key Influencer Targets (India)

| Influencer | Platform | Followers | Fit |
|------------|----------|-----------|-----|
| @1financebyzerodha | Instagram | 1M+ | Personal finance education |
| @thewealthymantra | YouTube | 500K | Investment tutorials |
| @pranjal_kamra | YouTube | 2M | Stock market (expand to alternatives) |
| @Finology | YouTube | 1M+ | Financial education |
| @AssetYogi | YouTube | 1M+ | Real estate, alternatives |

#### Launch Content Calendar

| Week | Content | Channel |
|------|---------|---------|
| -4 | "Why I built InvTracker" thread | Twitter |
| -3 | "The problem with tracking P2P investments" blog | LinkedIn |
| -2 | Teaser video - app preview | Instagram, YouTube |
| -1 | Early access waitlist | Product Hunt, Twitter |
| 0 | **Launch Day** - full announcement | All channels |
| +1 | Customer testimonial videos | YouTube, Instagram |
| +2 | "How to calculate XIRR" tutorial | YouTube |
| +3 | Comparison post: "Spreadsheet vs InvTracker" | Twitter |
| +4 | Feature deep-dive: AI document parser | LinkedIn |

#### Partnership Opportunities

| Partner Type | Companies | Collaboration |
|--------------|-----------|---------------|
| P2P Platforms | LendenClub, Faircent, 12% Club | Co-marketing, data export |
| FD Aggregators | BankBazaar, PaisaBazaar | Comparison content |
| Wealth Managers | Scripbox, Groww | Premium tier referral |
| CA Networks | ICAI chapters | Tax features promotion |

### Phase 2: International Expansion (Q3-Q4 2026)

#### Market Entry Priority

| Market | Strategy | Localization Needs |
|--------|----------|-------------------|
| **Singapore** | Partner with HNI wealth platforms | Multi-currency, SGD default |
| **UAE** | Target Indian expat community | AED support, real estate focus |
| **US** | Indian diaspora on Twitter/LinkedIn | USD, 1099 tax reports |
| **UK** | Property investment community | GBP, ISA tracking |

---

## 9. 90-Day Execution Plan

### Weeks 1-2: Technical Foundation

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| 1-2 | Complete remaining UI polish | Dev | [ ] |
| 3-4 | Add Firebase Analytics | Dev | [ ] |
| 5 | Add Crashlytics | Dev | [ ] |
| 6-7 | Write integration tests (auth flows) | Dev | [ ] |
| 8-10 | Write integration tests (investment flows) | Dev | [ ] |

### Weeks 3-4: Production Readiness

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| 11-12 | App Store developer account setup | Dev | [ ] |
| 13-14 | Create app store assets (screenshots, description) | Design | [ ] |
| 15-16 | Privacy policy and terms of service | Legal | [ ] |
| 17-18 | TestFlight internal testing | Dev | [ ] |
| 19-20 | Fix issues from testing | Dev | [ ] |

### Weeks 5-6: AI Document Parser (Start)

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| 21-22 | Set up Gemini API integration | Dev | [ ] |
| 23-25 | Build document upload UI | Dev | [ ] |
| 26-28 | Implement PDF text extraction | Dev | [ ] |
| 29-30 | Implement Excel/CSV parsing | Dev | [ ] |

### Weeks 7-8: AI Document Parser (Complete) + Notifications

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| 31-35 | AI extraction logic + verification UI | Dev | [ ] |
| 36-38 | Testing with real documents | QA | [ ] |
| 39-42 | Smart notifications implementation | Dev | [ ] |

### Weeks 9-10: Premium Paywall

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| 43-45 | RevenueCat integration | Dev | [ ] |
| 46-48 | Premium paywall UI | Dev | [ ] |
| 49-50 | Feature gating logic | Dev | [ ] |

### Weeks 11-12: Launch

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| 51-52 | Final testing and bug fixes | Dev/QA | [ ] |
| 53-54 | Submit to App Store | Dev | [ ] |
| 55-56 | Submit to Google Play | Dev | [ ] |
| 57-58 | Marketing launch preparation | Marketing | [ ] |
| 59-60 | **LAUNCH DAY** 🚀 | All | [ ] |

---

## 10. Success Metrics & KPIs

### North Star Metric

> **Monthly Active Investors (MAI)**: Users who logged at least one cash flow in the past 30 days

### Key Performance Indicators

#### User Acquisition Metrics

| Metric | Definition | Target (90 days) | Target (Year 1) |
|--------|------------|------------------|-----------------|
| Total Downloads | App store installs | 5,000 | 50,000 |
| Sign-up Rate | Downloads → Registered | 60% | 65% |
| Activation Rate | Registered → Added 1 investment | 40% | 50% |
| D1 Retention | Return next day | 30% | 40% |
| D7 Retention | Return within 7 days | 20% | 30% |
| D30 Retention | Return within 30 days | 10% | 20% |

#### Engagement Metrics

| Metric | Definition | Target |
|--------|------------|--------|
| DAU | Daily Active Users | 500 (90d), 5,000 (Y1) |
| MAU | Monthly Active Users | 2,000 (90d), 20,000 (Y1) |
| DAU/MAU Ratio | Stickiness | 25%+ |
| Avg Session Duration | Time in app | 3+ minutes |
| Cash Flows/User/Month | Core action frequency | 2+ |
| Investments/User | Portfolio size | 4+ |

#### Revenue Metrics

| Metric | Definition | Target (Year 1) |
|--------|------------|-----------------|
| Conversion Rate | Free → Paid | 5% |
| MRR | Monthly Recurring Revenue | ₹14L |
| ARPU | Avg Revenue Per User (paid) | ₹600/month |
| Churn Rate | Monthly subscription cancellation | <5% |
| LTV | Lifetime Value | ₹15,000 |
| CAC | Customer Acquisition Cost | <₹500 |
| LTV:CAC Ratio | Unit economics | >10:1 |

#### Product Quality Metrics

| Metric | Definition | Target |
|--------|------------|--------|
| App Store Rating | iOS + Android average | 4.5+ |
| Crash-free Rate | Sessions without crash | 99.5%+ |
| App Startup Time | Cold start | <2 seconds |
| Sync Success Rate | Firestore operations | 99.9%+ |
| XIRR Accuracy | Calculation correctness | 100% |

### Tracking Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│                    INVTRACKER DASHBOARD                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │    DAU       │ │    MAU       │ │   MRR (₹)    │        │
│  │    XXX       │ │    X,XXX     │ │   XX,XXX     │        │
│  │   +XX%       │ │   +XX%       │ │   +XX%       │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              WEEKLY ACTIVE USERS                      │  │
│  │   ▁▂▃▅▆▇█▇▆▅▃▂▁▂▃▅▆▇█▇▆▅▃▂▁                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  CONVERSION FUNNEL                                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Download  ████████████████████████████████  100%    │   │
│  │ Sign-up   ██████████████████████            60%     │   │
│  │ Activated ████████████                      40%     │   │
│  │ Retained  ██████                            20%     │   │
│  │ Premium   ██                                5%      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 11. Risk Assessment

### Product Risks

| Risk | Probability | Impact | Mitigation | Status |
|------|-------------|--------|------------|--------|
| Low user adoption | Medium | High | Focus on specific persona (P2P users first), iterate fast | [ ] Monitor |
| Feature overload | Medium | Medium | Strict MVP scope, user feedback before adding features | [ ] Active |
| Poor XIRR accuracy | Low | Critical | Extensive testing, comparison with Excel | [ ] Testing |
| Competitor entry | Medium | Medium | Move fast, build moat with AI parser + integrations | [ ] Watch |
| User data loss | Low | Critical | Firestore backups, local cache, export functionality | [ ] Mitigated |

### Technical Risks

| Risk | Probability | Impact | Mitigation | Status |
|------|-------------|--------|------------|--------|
| Firebase cost spike | Medium | Medium | Monitor usage, implement caching, set budget alerts | [ ] Monitor |
| Gemini API rate limits | Medium | Low | Queue system, fallback to manual entry | [ ] Plan |
| Offline sync conflicts | Low | Medium | Last-write-wins with user notification | [ ] Implemented |
| App rejection (stores) | Low | High | Follow guidelines, thorough testing | [ ] Prepare |
| Performance issues | Medium | Medium | Performance monitoring, optimization sprints | [ ] Plan |

### Business Risks

| Risk | Probability | Impact | Mitigation | Status |
|------|-------------|--------|------------|--------|
| Low conversion to paid | High | High | Validate pricing with early users, adjust tiers | [ ] Test |
| High churn | Medium | High | Improve onboarding, add sticky features (notifications) | [ ] Plan |
| Platform changes | Low | Medium | Abstract dependencies, monitor announcements | [ ] Monitor |
| Regulatory issues | Low | Medium | Consult legal for investment tracking apps | [ ] Research |
| Team scaling | Medium | Medium | Document everything, maintain code quality | [ ] Ongoing |

### Compliance Considerations

| Area | Requirement | Status |
|------|-------------|--------|
| Data Privacy | GDPR/DPDP compliance | [ ] Review |
| Financial Disclaimer | "Not financial advice" | [ ] Add |
| Terms of Service | User agreement | [ ] Draft |
| Privacy Policy | Data handling | [ ] Draft |
| SEBI Regulations | Not applicable (tracking tool) | [x] Confirmed |
| RBI Regulations | Not applicable (no transactions) | [x] Confirmed |

---

## 12. Goal Tracker

### Master Checklist by Phase

#### ✅ Phase 1: MVP (COMPLETE)

- [x] Firebase Firestore database with offline persistence
- [x] Google Sign-In via Firebase Auth
- [x] Investment CRUD operations
- [x] Investment lifecycle (Open/Closed with reopen)
- [x] Cash Flow ledger (INVEST, RETURN, INCOME, FEE)
- [x] XIRR calculation (Newton-Raphson)
- [x] MOIC calculation
- [x] CAGR calculation
- [x] Analytics dashboard with hero card
- [x] Monthly cash flow trend chart
- [x] Investment type distribution chart
- [x] Year-over-Year comparison
- [x] Recently closed investments card
- [x] Real-time multi-device sync
- [x] Bulk CSV import with template
- [x] Dark mode support
- [x] Premium paywall infrastructure
- [x] Cross-platform support (iOS, Android, Web, Desktop)
- [x] 3-tab navigation (Overview, Investments, Settings)

#### 🔧 Pre-Launch Technical (In Progress)

- [ ] **Integration Tests**
  - [ ] User sign-in flow
  - [ ] User sign-out flow
  - [ ] Create investment with cash flow
  - [ ] Add cash flow to investment
  - [ ] Edit cash flow
  - [ ] Delete cash flow
  - [ ] Close investment
  - [ ] Reopen investment
  - [ ] Bulk CSV import
  - [ ] Investment merge
  - [ ] Offline mode verification

- [ ] **Analytics & Monitoring**
  - [ ] Firebase Analytics integration
  - [ ] Crashlytics integration
  - [ ] Performance monitoring
  - [ ] Structured logging

- [ ] **Documentation**
  - [ ] ARCHITECTURE.md
  - [ ] API documentation
  - [ ] Contribution guidelines

- [ ] **App Store Preparation**
  - [ ] iOS Developer account
  - [ ] Google Play Developer account
  - [ ] App Store screenshots (6.5", 5.5")
  - [ ] Play Store screenshots
  - [ ] Feature graphic
  - [ ] App icon (all sizes)
  - [ ] Short description (80 chars)
  - [ ] Full description
  - [ ] Privacy policy URL
  - [ ] Terms of service URL
  - [ ] Support email
  - [ ] Marketing website

#### 📱 Phase 2: Intelligence & Automation (Q1 2026)

- [ ] **AI Document Parser**
  - [ ] Gemini API integration
  - [ ] PDF text extraction
  - [ ] Excel/CSV file parsing
  - [ ] Image OCR for scanned documents
  - [ ] Data extraction logic
  - [ ] User verification UI
  - [ ] Batch import from extraction
  - [ ] Error handling and fallbacks
  - [ ] Usage tracking (docs/month)

- [ ] **Smart Notifications**
  - [ ] Firebase Cloud Messaging setup
  - [ ] Cloud Functions for scheduling
  - [ ] Maturity reminder (7d, 3d, 1d)
  - [ ] Monthly income summary
  - [ ] Performance alerts
  - [ ] Milestone celebrations
  - [ ] Notification preferences UI
  - [ ] Push notification permissions

- [ ] **Recurring Income Projections**
  - [ ] Pattern recognition algorithm
  - [ ] Manual recurring setup
  - [ ] Calendar view of expected flows
  - [ ] 12-month projection chart
  - [ ] Accuracy tracking

- [ ] **Investment Insights**
  - [ ] Cross-category comparison logic
  - [ ] Natural language insight generation
  - [ ] Insight cards on dashboard
  - [ ] Personalized suggestions

#### 🌍 Phase 3: Portfolio Intelligence (Q2 2026)

- [ ] **Multi-Currency Support**
  - [ ] Currency selection per investment
  - [ ] Exchange rate API integration
  - [ ] Manual rate override option
  - [ ] Consolidated view in base currency
  - [ ] Currency breakdown analytics
  - [ ] Historical rate handling

- [ ] **Benchmark Comparison**
  - [ ] Nifty 50 data integration
  - [ ] S&P 500 data integration
  - [ ] FD rates (SBI/HDFC) data
  - [ ] Inflation (CPI) data
  - [ ] Gold price data
  - [ ] Time-period selection (1Y, 3Y, 5Y, All)
  - [ ] Visual chart overlay
  - [ ] Beat/lag messaging

- [ ] **Tax Reporting**
  - [ ] Financial year selector
  - [ ] Interest income calculation
  - [ ] Capital gains summary
  - [ ] TDS deducted summary
  - [ ] PDF export
  - [ ] Excel export
  - [ ] CA-ready formatting

- [ ] **Goal Tracking**
  - [ ] Goal creation UI
  - [ ] Link investments to goals
  - [ ] Progress visualization
  - [ ] Projected achievement date
  - [ ] Goal notifications

- [ ] **What-If Scenarios**
  - [ ] Scenario builder UI
  - [ ] Impact calculation engine
  - [ ] Save/compare scenarios
  - [ ] Visualization

#### 🔗 Phase 4: Connectivity (Q3 2026)

- [ ] **Bank Account Linking**
  - [ ] Account Aggregator partnership
  - [ ] Consent flow UI
  - [ ] Transaction pull mechanism
  - [ ] AI categorization
  - [ ] User confirmation flow
  - [ ] Recurring sync scheduling
  - [ ] Error handling

- [ ] **Broker Integration**
  - [ ] Zerodha Kite Connect
  - [ ] Groww API
  - [ ] ICICIDirect API
  - [ ] CAMS/KFintech for MF
  - [ ] Transaction import
  - [ ] Holdings sync

- [ ] **Family Accounts**
  - [ ] Family member invitation
  - [ ] Per-member portfolio
  - [ ] Combined dashboard
  - [ ] Permission controls
  - [ ] Data isolation

- [ ] **Advisor Sharing**
  - [ ] Share link generation
  - [ ] Time-limited access
  - [ ] Selective data sharing
  - [ ] Activity audit log
  - [ ] Revoke access

#### 💰 Phase 5: Community & Monetization (Q4 2026)

- [ ] **Premium Tier Enhancement**
  - [ ] RevenueCat full integration
  - [ ] Pro tier implementation
  - [ ] Family tier implementation
  - [ ] Advisor tier implementation
  - [ ] Feature gating
  - [ ] Trial periods
  - [ ] Upgrade prompts
  - [ ] Restore purchases

- [ ] **Anonymous Benchmarks**
  - [ ] Opt-in flow
  - [ ] Anonymization logic
  - [ ] Aggregation engine
  - [ ] Percentile calculation
  - [ ] Benchmark cards on dashboard

- [ ] **Investment Marketplace**
  - [ ] Platform directory structure
  - [ ] P2P platform listings
  - [ ] FD comparison
  - [ ] Bond platform listings
  - [ ] Referral link integration
  - [ ] Commission tracking

- [ ] **Advisory Connect**
  - [ ] Advisor onboarding
  - [ ] Directory UI
  - [ ] Consultation booking
  - [ ] Portfolio sharing for advisors
  - [ ] Lead tracking

### Go-To-Market Goals

#### Pre-Launch (4 weeks before)

- [ ] **Content Preparation**
  - [ ] "Why I built InvTracker" blog post
  - [ ] Product demo video (2 min)
  - [ ] Feature walkthrough videos (5x)
  - [ ] Social media graphics
  - [ ] Press kit

- [ ] **Community Building**
  - [ ] Twitter/X account active
  - [ ] LinkedIn page created
  - [ ] Product Hunt profile ready
  - [ ] Early access waitlist setup
  - [ ] 500+ waitlist signups

- [ ] **Partnerships**
  - [ ] Reach out to 10 P2P platforms
  - [ ] Connect with 5 personal finance influencers
  - [ ] CA network introduction

#### Launch Week

- [ ] Product Hunt launch
- [ ] Twitter announcement thread
- [ ] LinkedIn announcement
- [ ] Influencer posts go live
- [ ] Reddit posts (r/IndiaInvestments)
- [ ] Email to waitlist
- [ ] Press outreach

#### Post-Launch (ongoing)

- [ ] Weekly content calendar
- [ ] User testimonial collection
- [ ] App Store rating requests
- [ ] Feature announcement cycle
- [ ] Community engagement
- [ ] SEO for marketing website

### Quarterly Milestones

| Quarter | Milestone | Success Criteria |
|---------|-----------|------------------|
| Q1 2026 | **Production Launch** | 5,000 users, 500 MAU, app store approval |
| Q2 2026 | **Revenue Start** | 200 paid subscribers, ₹1.5L MRR |
| Q3 2026 | **Scale** | 20,000 users, 1,000 paid, ₹6L MRR |
| Q4 2026 | **Expansion** | 50,000 users, international beta, ₹14L MRR |

---

## Appendix A: Team Structure (Future)

### Current (Solo + AI)

| Role | Person | Responsibility |
|------|--------|----------------|
| Founder/Developer | You | Everything |
| AI Assistant | Augment | Development acceleration |

### Phase 2 Team (When ₹2L MRR achieved)

| Role | Type | Cost/Month | Responsibility |
|------|------|------------|----------------|
| Part-time Designer | Contract | ₹30K | UI polish, marketing assets |
| Part-time Marketer | Contract | ₹40K | Content, social media |

### Phase 3 Team (When ₹10L MRR achieved)

| Role | Type | Cost/Month | Responsibility |
|------|------|------------|----------------|
| Full-stack Developer | Full-time | ₹1.5L | Feature development |
| Designer | Full-time | ₹80K | Product design |
| Marketing Lead | Full-time | ₹1L | Growth, partnerships |
| Customer Success | Part-time | ₹40K | Support, onboarding |

---

## Appendix B: Competitive Landscape

| Competitor | Focus | Strengths | Weaknesses |
|------------|-------|-----------|------------|
| **Mint/Walnut** | Expense tracking | Brand, bank linking | No alternative investments |
| **INDMoney** | Wealth tracking | Bank linking, stocks | Complex, not focused on alternatives |
| **Groww** | Stock/MF | Great UX, trading | Only their platform |
| **Kuvera** | MF tracking | Goal-based | MF only |
| **Spreadsheets** | Manual tracking | Flexible | No automation, error-prone |
| **Nothing** | For alternatives | — | The gap we fill |

### Our Competitive Advantage

1. **Focus**: Only app dedicated to alternative investments
2. **Methodology**: Cash-flow based (not holdings-based)
3. **Metrics**: Professional XIRR, MOIC, CAGR
4. **Lifecycle**: Open → Closed management
5. **AI**: Document parsing (upcoming moat)
6. **Privacy**: User owns their data

---

## Appendix C: Technology Stack Reference

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| Framework | Flutter | 3.x | Cross-platform UI |
| Language | Dart | 3.x | Application logic |
| State | Riverpod | 2.x | State management |
| Database | Firebase Firestore | Latest | Cloud + offline storage |
| Auth | Firebase Auth | Latest | Google Sign-In |
| Analytics | Firebase Analytics | Latest | User tracking |
| Crashes | Firebase Crashlytics | Latest | Error reporting |
| Performance | Firebase Performance | Latest | App monitoring |
| Storage | Firebase Storage | Latest | Document uploads |
| Functions | Firebase Cloud Functions | Latest | Backend logic |
| AI | Google Gemini | Latest | Document parsing |
| Payments | RevenueCat | Latest | Subscriptions |
| Navigation | GoRouter | Latest | Routing |
| Charts | fl_chart | Latest | Visualizations |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-25 | CEO | Initial comprehensive roadmap |

---

*This document is the single source of truth for InvTracker product strategy and execution. Update regularly as goals are achieved and priorities shift.*

**Next Review Date**: January 15, 2026

