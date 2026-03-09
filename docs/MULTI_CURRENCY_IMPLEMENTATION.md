# Multi-Currency Implementation Guide - InvTrack

> **Complete implementation guide for multi-currency support with detailed touchpoints**

---

## 📋 **Table of Contents**

1. [Architecture Overview](#architecture-overview)
2. [Data Model](#data-model)
3. [Core Services](#core-services)
4. [User Touchpoints](#user-touchpoints)
5. [Implementation Plan](#implementation-plan)
6. [Testing Strategy](#testing-strategy)
7. [Migration Strategy](#migration-strategy)

---

## 🏗️ **Architecture Overview**

### **Design Principles**

1. **Store Minimal, Compute Smart**
   - Store only original amounts and currencies
   - Convert on-demand using cached rates
   - No pre-calculated conversions stored

2. **Three-Tier Caching**
   - **Tier 1:** Memory cache (current session, instant)
   - **Tier 2:** Firestore cache (persistent, offline)
   - **Tier 3:** Frankfurter API (fallback)

3. **Multi-Currency Cash Flows**
   - Each cash flow has its own currency
   - Investment has "primary" currency for display
   - Invested amount calculated from cash flows

4. **Performance First**
   - Batch conversion (1 API call per currency pair)
   - Lazy loading (convert only visible items)
   - Preload common rates (background on app start)

### **System Components**

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                            │
│  (Portfolio, Investment Detail, Add Cash Flow, Settings)    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                       │
│         (Providers: Portfolio, XIRR, Investment)            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                           │
│    (Entities: Investment, CashFlow, ConvertedCashFlow)      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       Service Layer                         │
│           (CurrencyConversionService)                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                        Data Layer                           │
│  (Firestore: Investments, Cash Flows, Exchange Rates)       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      External API                           │
│              (Frankfurter API)                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 **Data Model**

### **1. Investment Entity**

**Purpose:** Represents a single investment (stocks, bonds, FD, etc.)

**Fields:**
```dart
class InvestmentEntity {
  final String id;                    // Unique identifier
  final String name;                  // "US Tech Stocks"
  final InvestmentType type;          // stocks, bonds, fd, etc.
  final InvestmentStatus status;      // active, exited
  final String currency;              // Primary/display currency (USD, INR, EUR)
  final double investedAmount;        // Calculated from cash flows
  final double currentValue;          // Current market value
  final DateTime createdAt;           // Creation timestamp
  final DateTime? exitDate;           // Exit date (if exited)
}
```

**Firestore Structure:**
```
users/{userId}/investments/{investmentId}
{
  "id": "inv_123",
  "name": "US Tech Stocks",
  "type": "stocks",
  "status": "active",
  "currency": "USD",              // Primary currency
  "investedAmount": 10602,        // Calculated from cash flows
  "currentValue": 11000,          // In USD
  "createdAt": "2024-01-01T00:00:00Z",
  "exitDate": null
}
```

**Key Points:**
- `currency` is the "primary" or "display" currency
- `investedAmount` is calculated from all cash flows (may be in different currencies)
- `currentValue` is always in the primary currency

---

### **2. Cash Flow Entity**

**Purpose:** Represents a single transaction (buy, sell, dividend, etc.)

**Fields:**
```dart
class CashFlowEntity {
  final String id;                    // Unique identifier
  final String investmentId;          // Parent investment
  final DateTime date;                // Transaction date
  final CashFlowType type;            // buy, sell, dividend
  final double amount;                // Transaction amount
  final String currency;              // Cash flow's OWN currency
  final String? notes;                // Optional notes
  final DateTime createdAt;           // Creation timestamp
}
```

**Firestore Structure:**
```
users/{userId}/investments/{investmentId}/cashFlows/{cashFlowId}
{
  "id": "cf_456",
  "investmentId": "inv_123",
  "date": "2024-06-01",
  "type": "buy",
  "amount": 50000,
  "currency": "INR",              // Cash flow's currency (may differ from investment!)
  "notes": "Added from Indian bank account",
  "createdAt": "2024-06-01T14:30:00Z"
}
```

**Key Points:**
- Each cash flow has its **own** currency (not inherited from investment)
- Allows multi-currency cash flows for same investment
- Original amount and currency always preserved

---

### **3. Exchange Rate Cache**

**Purpose:** Cache exchange rates to minimize API calls

**Firestore Structure:**
```
users/{userId}/exchangeRates/{cacheKey}

// Historical rate (never expires)
historical_2024-01-01_USD_INR
{
  "type": "historical",
  "date": "2024-01-01",
  "from": "USD",
  "to": "INR",
  "rate": 83.00,
  "expiresAt": null,              // Never expires
  "fetchedAt": "2024-01-01T10:30:00Z"
}

// Live rate (expires end of day)
live_2026-02-13_USD_INR
{
  "type": "live",
  "date": "2026-02-13",
  "from": "USD",
  "to": "INR",
  "rate": 85.50,
  "expiresAt": "2026-02-13T23:59:59Z",
  "fetchedAt": "2026-02-13T10:30:00Z"
}
```

**Cache Key Format:** `{type}_{date}_{from}_{to}`

**Key Points:**
- Historical rates: Never expire (immutable)
- Live rates: Expire at end of day (auto-refresh)
- Separate cache per user (user-specific rates)

---

## ⚙️ **Core Services**

### **CurrencyConversionService**

**Purpose:** Central service for all currency conversions with three-tier caching

**Location:** `lib/core/services/currency_conversion_service.dart`

**Public API:**

```dart
class CurrencyConversionService {
  // Convert single amount
  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,  // null = use live rate
  });

  // Batch convert (optimized)
  Future<Map<String, double>> batchConvert({
    required Map<String, double> amounts,
    required String to,
  });

  // Preload common rates (background)
  Future<void> preloadRates(Set<String> currencies, String baseCurrency);

  // Refresh live cache (app start)
  Future<void> refreshLiveCacheOnAppStart();
}
```

**Implementation Details:**

#### **1. Three-Tier Caching**

```dart
class CurrencyConversionService {
  // Tier 1: Memory cache (current session)
  final Map<String, double> _memoryCache = {};

  // Tier 2: Firestore cache (persistent)
  final FirebaseFirestore _firestore;
  final String _userId;

  // Tier 3: Frankfurter API (fallback)
  final http.Client _httpClient;

  Future<double> convert({
    required double amount,
    required String from,
    required String to,
    DateTime? date,
  }) async {
    // Same currency = no conversion
    if (from == to) return amount;

    // Get rate using three-tier caching
    final rate = date != null
        ? await getHistoricalRate(date, from, to)
        : await getLiveRate(from, to);

    return amount * rate;
  }
}
```

#### **2. Historical Rate Fetching**

```dart
Future<double> getHistoricalRate(
  DateTime date,
  String from,
  String to,
) async {
  // 1. Check memory cache
  final memKey = 'historical_${_formatDate(date)}_${from}_$to';
  if (_memoryCache.containsKey(memKey)) {
    return _memoryCache[memKey]!;
  }

  // 2. Check Firestore cache
  final doc = await _firestore
      .collection('users')
      .doc(_userId)
      .collection('exchangeRates')
      .doc(memKey)
      .get();

  if (doc.exists) {
    final rate = doc.data()!['rate'] as double;
    _memoryCache[memKey] = rate;
    return rate;
  }

  // 3. Fetch from API
  final dateStr = _formatDate(date);
  final response = await _httpClient.get(
    Uri.parse('https://api.frankfurter.dev/v1/$dateStr?base=$from&symbols=$to'),
  );

  if (response.statusCode != 200) {
    throw CurrencyConversionException('Failed to fetch rate: ${response.statusCode}');
  }

  final data = jsonDecode(response.body);
  final rate = data['rates'][to] as double;

  // 4. Cache forever (historical rates never change)
  await _firestore
      .collection('users')
      .doc(_userId)
      .collection('exchangeRates')
      .doc(memKey)
      .set({
    'type': 'historical',
    'date': dateStr,
    'from': from,
    'to': to,
    'rate': rate,
    'expiresAt': null,
    'fetchedAt': FieldValue.serverTimestamp(),
  });

  _memoryCache[memKey] = rate;
  return rate;
}
```

#### **3. Live Rate Fetching**

```dart
Future<double> getLiveRate(String from, String to) async {
  final today = DateTime.now();
  final dateStr = _formatDate(today);

  // 1. Check memory cache
  final memKey = 'live_${dateStr}_${from}_$to';
  if (_memoryCache.containsKey(memKey)) {
    return _memoryCache[memKey]!;
  }

  // 2. Check Firestore cache (with expiration check)
  final doc = await _firestore
      .collection('users')
      .doc(_userId)
      .collection('exchangeRates')
      .doc(memKey)
      .get();

  if (doc.exists) {
    final data = doc.data()!;
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

    // Check if expired
    if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
      final rate = data['rate'] as double;
      _memoryCache[memKey] = rate;
      return rate;
    }
  }

  // 3. Fetch from API
  final response = await _httpClient.get(
    Uri.parse('https://api.frankfurter.dev/v1/latest?base=$from&symbols=$to'),
  );

  if (response.statusCode != 200) {
    throw CurrencyConversionException('Failed to fetch rate: ${response.statusCode}');
  }

  final data = jsonDecode(response.body);
  final rate = data['rates'][to] as double;

  // 4. Cache until end of day
  final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

  await _firestore
      .collection('users')
      .doc(_userId)
      .collection('exchangeRates')
      .doc(memKey)
      .set({
    'type': 'live',
    'date': dateStr,
    'from': from,
    'to': to,
    'rate': rate,
    'expiresAt': Timestamp.fromDate(endOfDay),
    'fetchedAt': FieldValue.serverTimestamp(),
  });

  _memoryCache[memKey] = rate;
  return rate;
}
```

#### **4. Batch Conversion (Optimized)**

```dart
Future<Map<String, double>> batchConvert({
  required Map<String, double> amounts,
  required String to,
}) async {
  final results = <String, double>{};

  // Group by currency, fetch rate once per currency
  for (final entry in amounts.entries) {
    final from = entry.key;
    final amount = entry.value;

    if (from == to) {
      results[from] = amount;
      continue;
    }

    // Fetch rate (uses three-tier caching)
    final rate = await getLiveRate(from, to);
    results[from] = amount * rate;
  }

  return results;
}
```

#### **5. Preload Common Rates**

```dart
Future<void> preloadRates(Set<String> currencies, String baseCurrency) async {
  // Run in background, don't block UI
  for (final currency in currencies) {
    if (currency == baseCurrency) continue;

    // Fetch rate (will cache automatically)
    unawaited(getLiveRate(from: currency, to: baseCurrency));
  }
}
```

#### **6. Smart Refresh on App Start**

```dart
Future<void> refreshLiveCacheOnAppStart() async {
  final prefs = await SharedPreferences.getInstance();
  final lastRefreshStr = prefs.getString('last_live_cache_refresh');

  if (lastRefreshStr != null) {
    final lastRefresh = DateTime.parse(lastRefreshStr);
    final hoursSinceRefresh = DateTime.now().difference(lastRefresh).inHours;

    if (hoursSinceRefresh < 1) {
      return; // Skip refresh (throttle)
    }
  }

  // Clear all live cache entries
  await _clearLiveCache();

  // Update last refresh time
  await prefs.setString('last_live_cache_refresh', DateTime.now().toIso8601String());
}

Future<void> _clearLiveCache() async {
  // Query all live cache entries
  final snapshot = await _firestore
      .collection('users')
      .doc(_userId)
      .collection('exchangeRates')
      .where('type', isEqualTo: 'live')
      .get();

  // Batch delete
  final batch = _firestore.batch();
  for (final doc in snapshot.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();

  // Clear memory cache
  _memoryCache.clear();
}
```

---

## 📱 **User Touchpoints**

### **Touchpoint 1: Add First Cash Flow (Same Currency)**

**User Journey:**
```
User opens Investment Detail → Taps "Add Transaction"
Enters: $10,000 USD on Jan 1, 2024
Currency: USD (matches investment)
Taps: Save
```

**System Flow:**

1. **Validate Input**
   - Amount > 0? ✅
   - Date valid? ✅
   - Currency selected? ✅

2. **Check Conversion Needed**
   - Cash flow currency: USD
   - Investment currency: USD
   - Same? ✅ No conversion needed

3. **Save to Firestore**
   ```
   users/{userId}/investments/{investmentId}/cashFlows/{cashFlowId}
   {
     "amount": 10000,
     "currency": "USD",
     "date": "2024-01-01",
     ...
   }
   ```

4. **Update Invested Amount**
   - Query all "buy" cash flows
   - Calculate total (no conversion needed)
   - Update investment.investedAmount = 10000

5. **UI Updates**
   - Investment Detail screen refreshes
   - Shows: "Invested: $10,000 USD"

**Performance:**
- API Calls: 0
- Cache Entries: 0
- Firestore Writes: 2 (cash flow + investment)
- Time: <500ms

---

### **Touchpoint 2: Add Second Cash Flow (Different Currency)**

**User Journey:**
```
User opens Investment Detail → Taps "Add Transaction"
Enters: ₹50,000 INR on Jun 1, 2024
Currency: INR (different from investment!)
Sees preview: "≈ $602 USD"
Taps: Save
```

**System Flow:**

1. **User Types Amount**
   - Detects: Currency (INR) ≠ Investment Currency (USD)
   - Triggers: Show conversion preview

2. **Fetch Live Rate for Preview**
   ```dart
   final preview = await service.convert(
     amount: 50000,
     from: 'INR',
     to: 'USD',
     date: null,  // Live rate
   );
   ```
   - Check memory cache: MISS
   - Check Firestore cache: MISS
   - Fetch from API: GET /latest?base=INR&symbols=USD
   - Result: 50000 × 0.01204 = $602 USD
   - Cache in memory + Firestore

3. **Show Preview**
   - UI updates: "≈ $602 USD (at current rate)"

4. **User Taps Save**
   - Save original amount: 50000 INR
   - Do NOT store converted amount
   - Do NOT store exchange rate

5. **Update Invested Amount**
   - Query all "buy" cash flows: [cf_001, cf_002]
   - Convert cf_001: $10,000 USD (no conversion)
   - Convert cf_002: ₹50,000 INR → $602 USD
     - Fetch historical rate for Jun 1, 2024
     - Check caches: MISS
     - Fetch from API: GET /2024-06-01?base=INR&symbols=USD
     - Cache forever (historical)
   - Total: $10,000 + $602 = $10,602 USD
   - Update investment.investedAmount = 10602

6. **UI Updates**
   - Shows both cash flows with conversions
   - "Jan 1: $10,000 USD"
   - "Jun 1: ₹50,000 INR ≈ $602 USD"

**Performance:**
- API Calls: 2 (1 live for preview, 1 historical for calculation)
- Cache Entries: 2 (live + historical)
- Firestore Writes: 4 (cash flow + 2 caches + investment)
- Time: <1 second

---

### **Touchpoint 3: View Portfolio (Different Base Currency)**

**User Journey:**
```
User's base currency: INR
Opens: Portfolio Overview
Has 3 investments: USD, EUR, GBP
```

**System Flow:**

1. **Load All Investments**
   - Query Firestore: users/{userId}/investments
   - Result: 3 investments with different currencies

2. **Identify Unique Currencies**
   - Scan: [USD, EUR, GBP]
   - User base: INR
   - Need: USD→INR, EUR→INR, GBP→INR

3. **Batch Convert (Optimized)**
   ```dart
   final amounts = {
     'USD': 11000,  // Total USD
     'EUR': 5000,   // Total EUR
     'GBP': 3000,   // Total GBP
   };

   final converted = await service.batchConvert(
     amounts: amounts,
     to: 'INR',
   );
   ```
   - Fetches 3 rates (one per currency)
   - All cached for future use

4. **Display Portfolio**
   - Total: ₹17,08,500 INR
   - US Tech: $11,000 → ₹9,40,500
   - EU Bonds: €5,000 → ₹4,50,000
   - UK Stocks: £3,000 → ₹3,18,000

**Performance:**
- API Calls: 3 (one per currency pair)
- Cache Entries: 3 (all live rates)
- Time: <1 second

---

### **Touchpoint 4: Calculate XIRR**

**User Journey:**
```
User opens Investment Detail
Taps: "View Returns"
```

**System Flow:**

1. **Load All Cash Flows**
   - Query: users/{userId}/investments/{id}/cashFlows
   - Result: 3 cash flows (USD, INR, USD)

2. **Convert Each to Base Currency**
   ```dart
   // cf_001: Jan 1, 2024, $10,000 USD → INR
   final cf1 = await service.convert(
     amount: 10000,
     from: 'USD',
     to: 'INR',
     date: DateTime(2024, 1, 1),  // Historical
   );
   // Result: ₹8,30,000 (cached)

   // cf_002: Jun 1, 2024, ₹50,000 INR → INR
   // No conversion needed

   // cf_003: Dec 1, 2024, $500 USD → INR
   final cf3 = await service.convert(
     amount: 500,
     from: 'USD',
     to: 'INR',
     date: DateTime(2024, 12, 1),  // Historical
   );
   // Result: ₹42,000 (cached)

   // Current value: $11,000 USD → INR
   final current = await service.convert(
     amount: 11000,
     from: 'USD',
     to: 'INR',
   );
   // Result: ₹9,40,500 (from memory cache!)
   ```

3. **Calculate XIRR**
   ```dart
   final cashFlows = [
     XirrCashFlow(date: DateTime(2024, 1, 1), amount: -830000),
     XirrCashFlow(date: DateTime(2024, 6, 1), amount: -50000),
     XirrCashFlow(date: DateTime(2024, 12, 1), amount: 42000),
     XirrCashFlow(date: DateTime.now(), amount: 940500),
   ];

   final xirr = calculateXirr(cashFlows);
   // Result: 12.5% per annum
   ```

4. **Display Returns**
   - XIRR: 12.5%
   - Shows all cash flows with conversions

**Performance:**
- API Calls: 2 (2 historical rates, 1 live from cache)
- Cache Entries: 2 (historical rates)
- Time: <500ms (most rates cached)

---

### **Touchpoint 5: Change Base Currency**

**User Journey:**
```
User opens Settings → Currency
Changes: INR → EUR
Taps: Save
```

**System Flow:**

1. **Update User Preference**
   ```dart
   await firestore
       .collection('users')
       .doc(userId)
       .update({'baseCurrency': 'EUR'});
   ```

2. **Trigger UI Rebuild**
   - currencyCodeProvider updates
   - All dependent providers rebuild
   - Portfolio, XIRR, etc. recalculate

3. **Portfolio Recalculates**
   - Batch convert to EUR (new base)
   - USD→EUR, GBP→EUR (fetch from API)
   - EUR→EUR (no conversion)

4. **Display Updated**
   - Total: €18,660 EUR
   - All values shown in EUR

**Performance:**
- API Calls: 2 (USD→EUR, GBP→EUR)
- Firestore Writes: 1 (user settings)
- Data Updates: 0 (no investment data changed!)
- Time: Instant (just UI refresh)

---

### **Touchpoint 6: App Restart (Next Day)**

**User Journey:**
```
Feb 14, 2026 (next day)
User opens InvTrack app
```

**System Flow:**

1. **Check Last Refresh**
   - SharedPreferences: "last_live_cache_refresh"
   - Last: Feb 13, 10:00
   - Now: Feb 14, 09:00
   - Difference: 23 hours

2. **Clear Live Cache**
   - Query: WHERE type = 'live'
   - Batch delete all live entries
   - Clear memory cache

3. **Preload Common Rates (Background)**
   ```dart
   final currencies = ['USD', 'EUR', 'GBP'];  // From portfolio
   final baseCurrency = 'EUR';

   for (final currency in currencies) {
     unawaited(service.getLiveRate(currency, baseCurrency));
   }
   ```
   - Runs in background
   - Doesn't block UI

4. **User Opens Portfolio**
   - Rates already preloaded!
   - Loads instantly

**Performance:**
- API Calls: 2 (preload in background)
- Time: <500ms (instant for user)

---

### **Touchpoint 7: Pull to Refresh**

**User Journey:**
```
30 minutes after app start
User pulls down on Portfolio
```

**System Flow:**

1. **Check Last Refresh**
   - Last: Feb 14, 09:00
   - Now: Feb 14, 09:30
   - Difference: 30 minutes

2. **Throttle Refresh**
   - <1 hour → Skip refresh
   - Show message: "Rates updated 30 min ago"

3. **No API Calls**
   - Uses cached rates
   - Instant response

**Performance:**
- API Calls: 0 (throttled)
- Time: Instant

---

## 🛠️ **Implementation Plan**

### **Phase 1: Core Infrastructure (Week 1)**

#### **1.1 Create CurrencyConversionService**

**File:** `lib/core/services/currency_conversion_service.dart`

**Tasks:**
- [ ] Create service class with three-tier caching
- [ ] Implement `convert()` method
- [ ] Implement `getHistoricalRate()` method
- [ ] Implement `getLiveRate()` method
- [ ] Implement `batchConvert()` method
- [ ] Implement `preloadRates()` method
- [ ] Implement `refreshLiveCacheOnAppStart()` method
- [ ] Add error handling and logging
- [ ] Create provider: `currencyConversionServiceProvider`

**Dependencies:**
- `http` package for API calls
- `shared_preferences` for last refresh tracking
- Firebase Firestore for cache

---

#### **1.2 Update Data Models**

**File:** `lib/features/investment/domain/entities/investment_entity.dart`

**Changes:**
```dart
class InvestmentEntity extends Equatable {
  // ... existing fields
  final String currency;  // ✅ ADD THIS

  const InvestmentEntity({
    // ... existing params
    required this.currency,  // ✅ ADD THIS
  });

  @override
  List<Object?> get props => [
    // ... existing props
    currency,  // ✅ ADD THIS
  ];
}
```

**File:** `lib/features/investment/domain/entities/transaction_entity.dart`

**Changes:**
```dart
class CashFlowEntity extends Equatable {
  // ... existing fields
  final String currency;  // ✅ ADD THIS

  const CashFlowEntity({
    // ... existing params
    required this.currency,  // ✅ ADD THIS
  });

  @override
  List<Object?> get props => [
    // ... existing props
    currency,  // ✅ ADD THIS
  ];
}
```

---

#### **1.3 Update Firestore Converters**

**File:** `lib/features/investment/data/models/investment_model.dart`

**Changes:**
```dart
factory InvestmentModel.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return InvestmentModel(
    // ... existing fields
    currency: data['currency'] as String? ?? 'USD',  // ✅ ADD THIS (default for migration)
  );
}

Map<String, dynamic> toFirestore() {
  return {
    // ... existing fields
    'currency': currency,  // ✅ ADD THIS
  };
}
```

**File:** `lib/features/investment/data/models/transaction_model.dart`

**Changes:**
```dart
factory CashFlowModel.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return CashFlowModel(
    // ... existing fields
    currency: data['currency'] as String? ?? investment.currency,  // ✅ ADD THIS (default for migration)
  );
}

Map<String, dynamic> toFirestore() {
  return {
    // ... existing fields
    'currency': currency,  // ✅ ADD THIS
  };
}
```

---

### **Phase 2: Business Logic (Week 2)**

#### **2.1 Update Invested Amount Calculation**

**File:** `lib/features/investment/presentation/providers/investment_providers.dart`

**Create New Provider:**
```dart
final investedAmountProvider = FutureProvider.family<double, String>(
  (ref, investmentId) async {
    final service = ref.read(currencyConversionServiceProvider);
    final investment = await ref.read(investmentProvider(investmentId).future);
    final cashFlows = await ref.read(cashFlowsProvider(investmentId).future);

    // Get all "buy" cash flows
    final buyCashFlows = cashFlows.where((cf) => cf.type == CashFlowType.buy);

    double totalInvested = 0.0;

    for (final cf in buyCashFlows) {
      final amountInInvestmentCurrency = await service.convert(
        amount: cf.amount,
        from: cf.currency,
        to: investment.currency,
        date: cf.date,
      );

      totalInvested += amountInInvestmentCurrency;
    }

    return totalInvested;
  },
);
```

---

#### **2.2 Update XIRR Calculation**

**File:** `lib/features/investment/presentation/providers/xirr_provider.dart`

**Update Provider:**
```dart
final xirrProvider = FutureProvider.family<double, String>(
  (ref, investmentId) async {
    final service = ref.read(currencyConversionServiceProvider);
    final userBaseCurrency = ref.read(currencyCodeProvider);
    final investment = await ref.read(investmentProvider(investmentId).future);
    final cashFlows = await ref.read(cashFlowsProvider(investmentId).future);

    final convertedCashFlows = <XirrCashFlow>[];

    // Convert each cash flow to user's base currency
    for (final cf in cashFlows) {
      final amountInBaseCurrency = await service.convert(
        amount: cf.amount,
        from: cf.currency,
        to: userBaseCurrency,
        date: cf.date,
      );

      final signedAmount = cf.type == CashFlowType.buy
          ? -amountInBaseCurrency
          : amountInBaseCurrency;

      convertedCashFlows.add(XirrCashFlow(
        date: cf.date,
        amount: signedAmount,
      ));
    }

    // Add current value
    final currentValueInBaseCurrency = await service.convert(
      amount: investment.currentValue,
      from: investment.currency,
      to: userBaseCurrency,
    );

    convertedCashFlows.add(XirrCashFlow(
      date: DateTime.now(),
      amount: currentValueInBaseCurrency,
    ));

    return calculateXirr(convertedCashFlows);
  },
);
```

---

#### **2.3 Update Portfolio Value Calculation**

**File:** `lib/features/portfolio/presentation/providers/portfolio_providers.dart`

**Update Provider:**
```dart
final portfolioValueProvider = FutureProvider<double>((ref) async {
  final service = ref.read(currencyConversionServiceProvider);
  final userCurrency = ref.read(currencyCodeProvider);
  final investments = await ref.read(investmentsProvider.future);

  // Group by currency for batch conversion
  final amounts = <String, double>{};
  for (final inv in investments) {
    amounts[inv.currency] = (amounts[inv.currency] ?? 0) + inv.currentValue;
  }

  // Batch convert
  final converted = await service.batchConvert(amounts: amounts, to: userCurrency);

  // Sum all converted values
  return converted.values.reduce((a, b) => a + b);
});
```

---

### **Phase 3: UI Updates (Week 3)**

#### **3.1 Add Currency Selector to Add Investment Screen**

**File:** `lib/features/investment/presentation/screens/add_investment_screen.dart`

**Add Widget:**
```dart
// Currency selector dropdown
DropdownButtonFormField<String>(
  value: _selectedCurrency,
  decoration: InputDecoration(
    labelText: l10n.currency,
    hintText: l10n.selectCurrency,
  ),
  items: supportedCurrencies.map((currency) {
    return DropdownMenuItem(
      value: currency.code,
      child: Text('${currency.code} - ${currency.name}'),
    );
  }).toList(),
  onChanged: (value) {
    setState(() {
      _selectedCurrency = value!;
    });
  },
  validator: (value) {
    if (value == null || value.isEmpty) {
      return l10n.pleaseSelectCurrency;
    }
    return null;
  },
),
```

---

#### **3.2 Add Currency Selector to Add Cash Flow Screen**

**File:** `lib/features/investment/presentation/screens/add_cash_flow_screen.dart`

**Add Widgets:**
```dart
// Currency selector
DropdownButtonFormField<String>(
  value: _selectedCurrency,
  items: supportedCurrencies.map((currency) {
    return DropdownMenuItem(
      value: currency.code,
      child: Text(currency.code),
    );
  }).toList(),
  onChanged: (value) {
    setState(() {
      _selectedCurrency = value!;
    });
  },
),

// Conversion preview (if different currency)
if (_selectedCurrency != investment.currency)
  FutureBuilder<double>(
    future: ref.read(currencyConversionServiceProvider).convert(
      amount: double.tryParse(_amountController.text) ?? 0,
      from: _selectedCurrency,
      to: investment.currency,
    ),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return SizedBox();

      return Text(
        '≈ ${snapshot.data} ${investment.currency}',
        style: TextStyle(color: Colors.grey),
      );
    },
  ),
```

---

#### **3.3 Update Investment Detail Screen**

**File:** `lib/features/investment/presentation/screens/investment_detail_screen.dart`

**Show Multi-Currency Cash Flows:**
```dart
// Cash flow tile with conversion
class CashFlowTile extends ConsumerWidget {
  final CashFlowEntity cashFlow;
  final String investmentCurrency;
  final String userCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(currencyConversionServiceProvider);

    return FutureBuilder<Map<String, double>>(
      future: Future.wait([
        service.convert(
          amount: cashFlow.amount,
          from: cashFlow.currency,
          to: investmentCurrency,
          date: cashFlow.date,
        ),
        service.convert(
          amount: cashFlow.amount,
          from: cashFlow.currency,
          to: userCurrency,
          date: cashFlow.date,
        ),
      ]).then((results) => {
        'investment': results[0],
        'user': results[1],
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListTile(
            title: Text('${cashFlow.amount} ${cashFlow.currency}'),
            subtitle: Text('Loading...'),
          );
        }

        final converted = snapshot.data!;

        return ListTile(
          title: Text('${cashFlow.amount} ${cashFlow.currency}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cashFlow.currency != investmentCurrency)
                Text('≈ ${converted['investment']} ${investmentCurrency}'),
              if (cashFlow.currency != userCurrency)
                Text('≈ ${converted['user']} ${userCurrency}'),
            ],
          ),
          trailing: Text(DateFormat('MMM d, y').format(cashFlow.date)),
        );
      },
    );
  }
}
```

---

### **Phase 4: App Initialization (Week 4)**

#### **4.1 Add Preload on App Start**

**File:** `lib/main.dart`

**Add to App Initialization:**
```dart
Future<void> _initializeApp() async {
  // ... existing initialization

  // Refresh live cache if needed
  final service = ref.read(currencyConversionServiceProvider);
  await service.refreshLiveCacheOnAppStart();

  // Preload common rates (background)
  final investments = await ref.read(investmentsProvider.future);
  final currencies = investments.map((inv) => inv.currency).toSet();
  final baseCurrency = ref.read(currencyCodeProvider);

  unawaited(service.preloadRates(currencies, baseCurrency));
}
```

---

#### **4.2 Add Pull-to-Refresh**

**File:** `lib/features/portfolio/presentation/screens/portfolio_overview_screen.dart`

**Add RefreshIndicator:**
```dart
RefreshIndicator(
  onRefresh: () async {
    final service = ref.read(currencyConversionServiceProvider);
    await service.refreshLiveCacheOnAppStart();
    ref.invalidate(portfolioValueProvider);
  },
  child: ListView(
    // ... portfolio content
  ),
),
```

---

## 🧪 **Testing Strategy**

### **Unit Tests**

#### **Test 1: CurrencyConversionService - Same Currency**

**File:** `test/core/services/currency_conversion_service_test.dart`

```dart
test('convert returns same amount when currencies are equal', () async {
  final service = CurrencyConversionService(/* ... */);

  final result = await service.convert(
    amount: 100,
    from: 'USD',
    to: 'USD',
  );

  expect(result, 100);
});
```

---

#### **Test 2: CurrencyConversionService - Historical Rate Caching**

```dart
test('historical rate is cached and reused', () async {
  final mockHttp = MockHttpClient();
  final service = CurrencyConversionService(httpClient: mockHttp);

  // First call - should hit API
  when(mockHttp.get(any)).thenAnswer((_) async => Response(
    '{"date":"2024-01-01","rates":{"INR":83.00}}',
    200,
  ));

  final result1 = await service.convert(
    amount: 100,
    from: 'USD',
    to: 'INR',
    date: DateTime(2024, 1, 1),
  );

  expect(result1, 8300);
  verify(mockHttp.get(any)).called(1);

  // Second call - should use cache
  final result2 = await service.convert(
    amount: 200,
    from: 'USD',
    to: 'INR',
    date: DateTime(2024, 1, 1),
  );

  expect(result2, 16600);
  verifyNever(mockHttp.get(any));  // No additional API call
});
```

---

#### **Test 3: CurrencyConversionService - Batch Conversion**

```dart
test('batch convert groups by currency', () async {
  final mockHttp = MockHttpClient();
  final service = CurrencyConversionService(httpClient: mockHttp);

  when(mockHttp.get(any)).thenAnswer((_) async => Response(
    '{"rates":{"INR":83.00}}',
    200,
  ));

  final result = await service.batchConvert(
    amounts: {
      'USD': 100,
      'USD': 200,  // Same currency
      'EUR': 150,
    },
    to: 'INR',
  );

  // Should make only 2 API calls (USD→INR, EUR→INR)
  verify(mockHttp.get(any)).called(2);
});
```

---

#### **Test 4: Invested Amount Calculation - Multi-Currency**

**File:** `test/features/investment/presentation/providers/investment_providers_test.dart`

```dart
test('invested amount calculated from multi-currency cash flows', () async {
  final container = ProviderContainer(
    overrides: [
      currencyConversionServiceProvider.overrideWithValue(mockService),
    ],
  );

  when(mockService.convert(
    amount: 10000,
    from: 'USD',
    to: 'USD',
    date: any,
  )).thenAnswer((_) async => 10000);

  when(mockService.convert(
    amount: 50000,
    from: 'INR',
    to: 'USD',
    date: any,
  )).thenAnswer((_) async => 602);

  final result = await container.read(
    investedAmountProvider('inv_123').future,
  );

  expect(result, 10602);  // $10,000 + $602
});
```

---

#### **Test 5: XIRR Calculation - Multi-Currency**

**File:** `test/features/investment/presentation/providers/xirr_provider_test.dart`

```dart
test('XIRR calculated with multi-currency cash flows', () async {
  final container = ProviderContainer(
    overrides: [
      currencyConversionServiceProvider.overrideWithValue(mockService),
      currencyCodeProvider.overrideWith((ref) => 'INR'),
    ],
  );

  // Mock conversions
  when(mockService.convert(
    amount: 10000,
    from: 'USD',
    to: 'INR',
    date: DateTime(2024, 1, 1),
  )).thenAnswer((_) async => 830000);

  when(mockService.convert(
    amount: 50000,
    from: 'INR',
    to: 'INR',
    date: DateTime(2024, 6, 1),
  )).thenAnswer((_) async => 50000);

  final result = await container.read(
    xirrProvider('inv_123').future,
  );

  expect(result, closeTo(0.125, 0.01));  // 12.5% XIRR
});
```

---

### **Widget Tests**

#### **Test 6: Add Cash Flow Screen - Currency Selector**

**File:** `test/features/investment/presentation/screens/add_cash_flow_screen_test.dart`

```dart
testWidgets('shows currency selector', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: AddCashFlowScreen(investmentId: 'inv_123'),
      ),
    ),
  );

  // Find currency dropdown
  expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

  // Tap dropdown
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();

  // Verify currencies shown
  expect(find.text('USD'), findsOneWidget);
  expect(find.text('INR'), findsOneWidget);
  expect(find.text('EUR'), findsOneWidget);
});
```

---

#### **Test 7: Add Cash Flow Screen - Conversion Preview**

```dart
testWidgets('shows conversion preview for different currency', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currencyConversionServiceProvider.overrideWithValue(mockService),
      ],
      child: MaterialApp(
        home: AddCashFlowScreen(investmentId: 'inv_123'),
      ),
    ),
  );

  // Enter amount
  await tester.enterText(find.byType(TextField), '50000');

  // Select different currency
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('INR'));
  await tester.pumpAndSettle();

  // Verify preview shown
  expect(find.textContaining('≈'), findsOneWidget);
  expect(find.textContaining('USD'), findsOneWidget);
});
```

---

### **Integration Tests**

#### **Test 8: End-to-End Multi-Currency Flow**

**File:** `integration_test/multi_currency_test.dart`

```dart
testWidgets('complete multi-currency flow', (tester) async {
  // 1. Add investment with USD
  await tester.tap(find.text('Add Investment'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(Key('name')), 'US Tech Stocks');
  await tester.tap(find.text('USD'));
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  // 2. Add cash flow in USD
  await tester.tap(find.text('Add Transaction'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(Key('amount')), '10000');
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  // 3. Add cash flow in INR
  await tester.tap(find.text('Add Transaction'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(Key('amount')), '50000');
  await tester.tap(find.byKey(Key('currency')));
  await tester.tap(find.text('INR'));
  await tester.pumpAndSettle();

  // Verify preview shown
  expect(find.textContaining('≈'), findsOneWidget);

  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  // 4. Verify invested amount
  expect(find.textContaining('10,602'), findsOneWidget);

  // 5. Change base currency
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Currency'));
  await tester.tap(find.text('EUR'));
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  // 6. Verify portfolio recalculated
  await tester.tap(find.text('Portfolio'));
  await tester.pumpAndSettle();

  expect(find.textContaining('EUR'), findsWidgets);
});
```

---

## 🔄 **Migration Strategy**

### **Migration Plan**

#### **Step 1: Add Currency Fields (Non-Breaking)**

**Goal:** Add currency fields with defaults, don't break existing data

**Changes:**
```dart
// Investment Model
factory InvestmentModel.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return InvestmentModel(
    // ... existing fields
    currency: data['currency'] as String? ?? 'USD',  // Default to USD
  );
}
```

**Firestore Rules Update:**
```javascript
// Allow currency field (optional for now)
match /users/{userId}/investments/{investmentId} {
  allow write: if request.resource.data.currency is string ||
                  !request.resource.data.keys().hasAny(['currency']);
}
```

---

#### **Step 2: Backfill Existing Data**

**Goal:** Add currency field to all existing investments and cash flows

**Migration Script:**
```dart
Future<void> migrateExistingData() async {
  final firestore = FirebaseFirestore.instance;

  // Get all users
  final usersSnapshot = await firestore.collection('users').get();

  for (final userDoc in usersSnapshot.docs) {
    final userId = userDoc.id;

    // Get user's default currency
    final userData = userDoc.data();
    final defaultCurrency = userData['baseCurrency'] as String? ?? 'USD';

    // Migrate investments
    final investmentsSnapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('investments')
        .get();

    final batch = firestore.batch();

    for (final invDoc in investmentsSnapshot.docs) {
      final invData = invDoc.data();

      // Skip if already has currency
      if (invData.containsKey('currency')) continue;

      // Add currency field
      batch.update(invDoc.reference, {
        'currency': defaultCurrency,
      });

      // Migrate cash flows
      final cashFlowsSnapshot = await invDoc.reference
          .collection('cashFlows')
          .get();

      for (final cfDoc in cashFlowsSnapshot.docs) {
        final cfData = cfDoc.data();

        // Skip if already has currency
        if (cfData.containsKey('currency')) continue;

        // Add currency field (same as investment)
        batch.update(cfDoc.reference, {
          'currency': defaultCurrency,
        });
      }
    }

    await batch.commit();
    print('Migrated user: $userId');
  }

  print('Migration complete!');
}
```

**Run Migration:**
```dart
// In main.dart (one-time)
if (kDebugMode) {
  await migrateExistingData();
}
```

---

#### **Step 3: Make Currency Required**

**Goal:** After migration, make currency field required

**Firestore Rules Update:**
```javascript
match /users/{userId}/investments/{investmentId} {
  allow write: if request.resource.data.currency is string;  // Required
}

match /users/{userId}/investments/{investmentId}/cashFlows/{cashFlowId} {
  allow write: if request.resource.data.currency is string;  // Required
}
```

---

#### **Step 4: Deploy UI Changes**

**Goal:** Roll out UI changes to users

**Deployment Steps:**
1. Deploy backend changes (currency fields optional)
2. Run migration script (backfill data)
3. Deploy app update (with currency selectors)
4. Monitor for errors
5. Make currency fields required (after 100% migration)

---

### **Rollback Plan**

**If Issues Occur:**

1. **Revert App Update**
   - Roll back to previous version
   - Currency fields remain in Firestore (harmless)

2. **Remove Currency Fields (if needed)**
   ```dart
   Future<void> rollbackMigration() async {
     final firestore = FirebaseFirestore.instance;

     // Get all users
     final usersSnapshot = await firestore.collection('users').get();

     for (final userDoc in usersSnapshot.docs) {
       final userId = userDoc.id;

       // Remove currency from investments
       final investmentsSnapshot = await firestore
           .collection('users')
           .doc(userId)
           .collection('investments')
           .get();

       final batch = firestore.batch();

       for (final invDoc in investmentsSnapshot.docs) {
         batch.update(invDoc.reference, {
           'currency': FieldValue.delete(),
         });

         // Remove currency from cash flows
         final cashFlowsSnapshot = await invDoc.reference
             .collection('cashFlows')
             .get();

         for (final cfDoc in cashFlowsSnapshot.docs) {
           batch.update(cfDoc.reference, {
             'currency': FieldValue.delete(),
           });
         }
       }

       await batch.commit();
     }
   }
   ```

---

## ✅ **Implementation Checklist**

### **Phase 1: Core Infrastructure**
- [ ] Create CurrencyConversionService
- [ ] Implement three-tier caching
- [ ] Add currency field to InvestmentEntity
- [ ] Add currency field to CashFlowEntity
- [ ] Update Firestore converters
- [ ] Create unit tests for service

### **Phase 2: Business Logic**
- [ ] Update invested amount calculation
- [ ] Update XIRR calculation
- [ ] Update portfolio value calculation
- [ ] Create providers for conversions
- [ ] Add unit tests for calculations

### **Phase 3: UI Updates**
- [ ] Add currency selector to Add Investment
- [ ] Add currency selector to Add Cash Flow
- [ ] Show conversion preview
- [ ] Update Investment Detail screen
- [ ] Update Portfolio Overview screen
- [ ] Add widget tests

### **Phase 4: App Initialization**
- [ ] Add preload on app start
- [ ] Add pull-to-refresh
- [ ] Add smart cache refresh
- [ ] Add integration tests

### **Phase 5: Migration**
- [ ] Write migration script
- [ ] Test migration on staging
- [ ] Run migration on production
- [ ] Monitor for errors
- [ ] Make currency fields required

### **Phase 6: Documentation**
- [ ] Update user guide
- [ ] Update API documentation
- [ ] Update architecture docs
- [ ] Create troubleshooting guide

---

## 🎯 **Success Metrics**

### **Performance Targets**
- Portfolio load: <1 second
- XIRR calculation: <500ms (cached)
- API calls: <5 per session
- Cache hit rate: >90%

### **User Experience**
- Zero data loss during migration
- Smooth currency switching
- Clear conversion previews
- Accurate XIRR calculations

### **Technical**
- Test coverage: >80%
- Zero critical bugs
- Offline support maintained
- Multi-device sync working

---

## 📚 **References**

- [Frankfurter API Documentation](https://www.frankfurter.app/docs/)
- [MULTI_CURRENCY_STRATEGY.md](./MULTI_CURRENCY_STRATEGY.md)
- [EXCHANGE_RATES_API_RESEARCH.md](./EXCHANGE_RATES_API_RESEARCH.md)
- [InvTrack Enterprise Rules](../.augment/rules/invtrack_rules.md)

---

**End of Implementation Guide** 🎉

