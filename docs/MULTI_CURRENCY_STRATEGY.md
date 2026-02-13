# Multi-Currency Strategy - InvTrack

> **When to use Historical vs Current Exchange Rates**

---

## 🎯 **Core Principle**

**Historical rates for past transactions, Current rates for present values**

---

## 📊 **Complete Flow Explanation**

### **Scenario: User Portfolio**

**User's Base Currency:** INR (Indian Rupee)

**Investments:**
1. **US Stocks** - $10,000 USD (bought Jan 1, 2024)
2. **European Bonds** - €5,000 EUR (bought Jun 1, 2024)
3. **Indian FD** - ₹1,00,000 INR (bought Dec 1, 2024)

---

## 🔄 **When to Use Historical Rates**

### **Use Case 1: Recording Past Transactions**

**When:** User adds a transaction (buy/sell/dividend) with a past date

**Why:** To accurately record what the investment was worth **on that specific date**

**Example:**
```dart
// User bought $10,000 USD on Jan 1, 2024
Transaction Date: Jan 1, 2024
Amount: $10,000 USD
Exchange Rate on Jan 1, 2024: 1 USD = 83.00 INR

// Store in database:
{
  "date": "2024-01-01",
  "amount": 10000,
  "currency": "USD",
  "exchangeRate": 83.00,           // Historical rate on transaction date
  "convertedAmount": 830000,       // 10000 × 83 = ₹8,30,000
  "baseCurrency": "INR"
}
```

**Result:** Transaction recorded as ₹8,30,000 INR (what it was actually worth on Jan 1, 2024)

---

### **Use Case 2: XIRR Calculation**

**When:** Calculating time-weighted returns (XIRR)

**Why:** XIRR uses exact dates, so we need exact rates on those dates

**Example:**
```dart
// Cash flows for US Stocks investment
Cash Flow 1: Jan 1, 2024 → -$10,000 USD → -₹8,30,000 INR (@ 83.00)
Cash Flow 2: Jun 1, 2024 → +$500 USD (dividend) → +₹41,500 INR (@ 83.00)
Cash Flow 3: Feb 13, 2026 → $11,000 USD (current value) → ₹9,35,000 INR (@ 85.00)

// XIRR calculation uses these converted amounts
XIRR = calculateXirr([
  {date: 2024-01-01, amount: -830000},  // Historical rate
  {date: 2024-06-01, amount: +41500},   // Historical rate
  {date: 2026-02-13, amount: +935000},  // Current rate
])
```

**Result:** Accurate time-weighted return calculation

---

## 📈 **When to Use Current Rates**

### **Use Case 3: Live Portfolio Value (Current Holdings)**

**When:** Displaying current portfolio value / outstanding investments

**Why:** To show what the portfolio is worth **right now** (today)

**Example:**
```dart
// Today: Feb 13, 2026
// Current exchange rates (from Frankfurter latest API):
1 USD = 85.00 INR
1 EUR = 90.00 INR

// User's current holdings:
US Stocks: $11,000 USD × 85.00 = ₹9,35,000 INR
European Bonds: €5,500 EUR × 90.00 = ₹4,95,000 INR
Indian FD: ₹1,00,000 INR × 1.00 = ₹1,00,000 INR

// Total Portfolio Value (in INR):
₹9,35,000 + ₹4,95,000 + ₹1,00,000 = ₹15,30,000 INR
```

**Result:** User sees their portfolio is worth ₹15,30,000 INR **today**

---

### **Use Case 4: Adding Today's Transaction**

**When:** User adds a transaction with today's date

**Why:** Use the most recent available rate (yesterday's closing or today's rate)

**Example:**
```dart
// User buys $5,000 USD today (Feb 13, 2026)
Transaction Date: Feb 13, 2026
Amount: $5,000 USD

// Fetch latest rate from Frankfurter
GET https://api.frankfurter.dev/v1/latest?base=USD&symbols=INR

// Response:
{
  "base": "USD",
  "date": "2026-02-12",  // Yesterday's closing rate (most recent)
  "rates": {
    "INR": 85.00
  }
}

// Store in database:
{
  "date": "2026-02-13",
  "amount": 5000,
  "currency": "USD",
  "exchangeRate": 85.00,           // Latest available rate
  "convertedAmount": 425000,       // 5000 × 85 = ₹4,25,000
  "baseCurrency": "INR"
}
```

**Result:** Transaction recorded with most recent rate available

---

## 🏗️ **Implementation Strategy**

### **1. Transaction Entry Flow**

```dart
Future<void> addTransaction({
  required DateTime date,
  required double amount,
  required String currency,
}) async {
  final userBaseCurrency = ref.read(currencyCodeProvider); // e.g., "INR"
  
  // If transaction is in base currency, no conversion needed
  if (currency == userBaseCurrency) {
    await _saveTransaction(
      date: date,
      amount: amount,
      currency: currency,
      exchangeRate: 1.0,
      convertedAmount: amount,
    );
    return;
  }
  
  // Fetch exchange rate for transaction date
  final rate = await _getExchangeRateForDate(
    date: date,
    from: currency,
    to: userBaseCurrency,
  );
  
  // Store BOTH original and converted amounts
  await _saveTransaction(
    date: date,
    amount: amount,
    currency: currency,
    exchangeRate: rate,
    convertedAmount: amount * rate,
  );
}
```

---

### **2. Exchange Rate Fetching Logic**

```dart
Future<double> _getExchangeRateForDate({
  required DateTime date,
  required String from,
  required String to,
}) async {
  // 1. Check cache first
  final cachedRate = await _getCachedRate(date, from, to);
  if (cachedRate != null) {
    return cachedRate;
  }
  
  // 2. Determine which API endpoint to use
  final dateStr = DateFormat('yyyy-MM-dd').format(date);
  final today = DateTime.now();
  final isToday = date.year == today.year && 
                  date.month == today.month && 
                  date.day == today.day;
  
  String apiUrl;
  if (isToday) {
    // Use latest rate (yesterday's closing)
    apiUrl = 'https://api.frankfurter.dev/v1/latest?base=$from&symbols=$to';
  } else {
    // Use historical rate for specific date
    apiUrl = 'https://api.frankfurter.dev/v1/$dateStr?base=$from&symbols=$to';
  }
  
  // 3. Fetch from Frankfurter
  final response = await http.get(Uri.parse(apiUrl));
  final data = jsonDecode(response.body);
  final rate = data['rates'][to];
  
  // 4. Cache the rate (never expires for historical dates)
  await _cacheRate(date, from, to, rate);
  
  return rate;
}
```

---

### **3. Portfolio Value Calculation**

```dart
Future<double> calculatePortfolioValue() async {
  final investments = await ref.read(investmentsProvider.future);
  final userBaseCurrency = ref.read(currencyCodeProvider);
  
  double totalValue = 0.0;
  
  for (final investment in investments) {
    // Get current value in investment's currency
    final currentValueInOriginalCurrency = investment.currentValue;
    final investmentCurrency = investment.currency;
    
    // If already in base currency, no conversion needed
    if (investmentCurrency == userBaseCurrency) {
      totalValue += currentValueInOriginalCurrency;
      continue;
    }
    
    // Fetch LATEST exchange rate for current value
    final currentRate = await _getLatestExchangeRate(
      from: investmentCurrency,
      to: userBaseCurrency,
    );
    
    // Convert to base currency
    final convertedValue = currentValueInOriginalCurrency * currentRate;
    totalValue += convertedValue;
  }
  
  return totalValue;
}

Future<double> _getLatestExchangeRate({
  required String from,
  required String to,
}) async {
  // Check if we have today's rate cached
  final today = DateTime.now();
  final cachedRate = await _getCachedRate(today, from, to);
  if (cachedRate != null) {
    return cachedRate;
  }
  
  // Fetch latest rate
  final response = await http.get(
    Uri.parse('https://api.frankfurter.dev/v1/latest?base=$from&symbols=$to'),
  );
  final data = jsonDecode(response.body);
  final rate = data['rates'][to];
  
  // Cache for today (will be refreshed tomorrow)
  await _cacheRate(today, from, to, rate);
  
  return rate;
}
```

---

## 💾 **Caching Strategy**

### **Firestore Structure**

```
users/{userId}/exchangeRates/{cacheKey}
{
  "date": "2024-01-01",
  "from": "USD",
  "to": "INR",
  "rate": 83.00,
  "fetchedAt": "2024-01-01T10:30:00Z",
  "isHistorical": true  // Never expires
}

users/{userId}/exchangeRates/{cacheKey}
{
  "date": "2026-02-13",
  "from": "USD",
  "to": "INR",
  "rate": 85.00,
  "fetchedAt": "2026-02-13T10:30:00Z",
  "isHistorical": false  // Expires after 24 hours
}
```

**Cache Key Format:** `{date}_{from}_{to}` (e.g., `2024-01-01_USD_INR`)

### **Cache Expiration Logic**

```dart
Future<double?> _getCachedRate(DateTime date, String from, String to) async {
  final cacheKey = '${DateFormat('yyyy-MM-dd').format(date)}_${from}_$to';
  final doc = await firestore
      .collection('users')
      .doc(userId)
      .collection('exchangeRates')
      .doc(cacheKey)
      .get();
  
  if (!doc.exists) return null;
  
  final data = doc.data()!;
  final isHistorical = data['isHistorical'] as bool;
  
  // Historical rates never expire
  if (isHistorical) {
    return data['rate'] as double;
  }
  
  // Current rates expire after 24 hours
  final fetchedAt = (data['fetchedAt'] as Timestamp).toDate();
  final age = DateTime.now().difference(fetchedAt);
  
  if (age.inHours < 24) {
    return data['rate'] as double;
  }
  
  // Expired - return null to trigger fresh fetch
  return null;
}
```

---

## 📱 **UI Display Examples**

### **Investment Detail Screen**

```
┌─────────────────────────────────────────┐
│ US Tech Stocks                          │
├─────────────────────────────────────────┤
│ Original Amount:    $10,000 USD         │
│ Invested On:        Jan 1, 2024         │
│ Rate Used:          @ 83.00 INR/USD     │
│ Invested (INR):     ₹8,30,000           │
│                                         │
│ Current Value:      $11,000 USD         │
│ Current Rate:       @ 85.00 INR/USD     │
│ Current Value (INR): ₹9,35,000          │
│                                         │
│ Gain:               ₹1,05,000 (+12.7%)  │
└─────────────────────────────────────────┘
```

### **Portfolio Overview**

```
┌─────────────────────────────────────────┐
│ Total Portfolio Value                   │
│ ₹15,30,000 INR                          │
│ (as of Feb 13, 2026)                    │
├─────────────────────────────────────────┤
│ US Stocks:      $11,000 → ₹9,35,000    │
│ EU Bonds:       €5,500  → ₹4,95,000    │
│ Indian FD:      ₹1,00,000               │
└─────────────────────────────────────────┘
```

---

## ✅ **Summary**

| Use Case | Rate Type | API Endpoint | Cache Duration |
|----------|-----------|--------------|----------------|
| **Past Transaction** | Historical | `/v1/{date}` | Forever |
| **Today's Transaction** | Latest | `/v1/latest` | 24 hours |
| **XIRR Calculation** | Historical | Cached | Forever |
| **Current Portfolio Value** | Latest | `/v1/latest` | 24 hours |
| **Investment Detail** | Both | Both | Mixed |

**Key Insight:** Historical rates for accuracy, Current rates for relevance! 🎯

