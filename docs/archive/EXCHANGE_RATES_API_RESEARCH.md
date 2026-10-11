# Exchange Rates API Research - InvTrack Multi-Currency Support

> **Research Date:** 2026-02-13  
> **Purpose:** Select the best exchange rates API for InvTrack's multi-currency support feature

---

## 📊 API Comparison Summary

| API | Free Tier | Rate Limit | Currencies | Historical Data | API Key Required | Self-Hostable | Recommendation |
|-----|-----------|------------|------------|-----------------|------------------|---------------|----------------|
| **Frankfurter** | ✅ Unlimited | ✅ No limit | 33 (ECB) | ✅ Since 1999 | ❌ No | ✅ Yes (Docker) | **⭐ RECOMMENDED** |
| **ExchangeRate-API** | ✅ 1,500/month | 1,500 req/month | 161 | ✅ Yes | ✅ Yes (free) | ❌ No | Good alternative |
| **Currencylayer** | ✅ 100/month | 100 req/month | 168 | ❌ Paid only | ✅ Yes | ❌ No | Too restrictive |
| **Open Exchange Rates** | ✅ 1,000/month | 1,000 req/month | 200 | ❌ Paid only | ✅ Yes | ❌ No | Too restrictive |
| **Fixer.io** | ✅ 100/month | 100 req/month | 170 | ❌ Paid only | ✅ Yes | ❌ No | Too restrictive |

---

## ⭐ **RECOMMENDED: Frankfurter API**

### Why Frankfurter?

1. **✅ Completely Free & Unlimited**
   - No API key required
   - No rate limits
   - No usage caps
   - Free for commercial use

2. **✅ Self-Hostable**
   - Open-source (MIT License)
   - Docker support: `docker run -d -p 80:8080 lineofflight/frankfurter`
   - Full control over data and uptime

3. **✅ Reliable Data Source**
   - Uses European Central Bank (ECB) reference rates
   - Updated daily around 16:00 CET
   - Historical data since 1999

4. **✅ Simple REST API**
   - No authentication required
   - Clean JSON responses
   - Works great in mobile apps

5. **✅ Privacy-Friendly**
   - No personal data collection
   - Runs behind Cloudflare for performance
   - Can self-host for complete privacy

### Supported Currencies (33 total)

```
AUD, BGN, BRL, CAD, CHF, CNY, CZK, DKK, EUR, GBP, HKD, HUF, IDR, ILS, INR, ISK, 
JPY, KRW, MXN, MYR, NOK, NZD, PHP, PLN, RON, SEK, SGD, THB, TRY, USD, ZAR, etc.
```

**Coverage:** Covers all 14 currencies currently supported in InvTrack + 19 more!

### API Endpoints

#### 1. Latest Rates
```bash
GET https://api.frankfurter.dev/v1/latest
GET https://api.frankfurter.dev/v1/latest?base=USD
GET https://api.frankfurter.dev/v1/latest?base=USD&symbols=EUR,GBP,INR
```

**Response:**
```json
{
  "base": "USD",
  "date": "2026-02-13",
  "rates": {
    "EUR": 0.92,
    "GBP": 0.79,
    "INR": 83.25
  }
}
```

#### 2. Historical Rates
```bash
GET https://api.frankfurter.dev/v1/2026-01-01
GET https://api.frankfurter.dev/v1/2026-01-01?base=USD&symbols=EUR
```

#### 3. Time Series
```bash
GET https://api.frankfurter.dev/v1/2026-01-01..2026-01-31
GET https://api.frankfurter.dev/v1/2026-01-01..?symbols=USD,EUR
```

#### 4. Available Currencies
```bash
GET https://api.frankfurter.dev/v1/currencies
```

**Response:**
```json
{
  "AUD": "Australian Dollar",
  "EUR": "Euro",
  "GBP": "British Pound",
  "INR": "Indian Rupee",
  "USD": "US Dollar",
  "..."
}
```

### Implementation Strategy

#### 1. **Daily Rate Updates**
- Fetch latest rates once per day (around 16:00 CET)
- Cache rates locally in Firestore
- Use cached rates for all conversions
- Fallback to last known rates if API is unavailable

#### 2. **Offline-First Approach**
- Store exchange rates in Firestore: `users/{userId}/exchangeRates/{date}`
- Cache rates for 7 days
- Use last known rates when offline
- Show "Last updated: X hours ago" indicator

#### 3. **Rate Refresh Logic**
```dart
// Pseudo-code
if (lastUpdateTime > 24 hours ago) {
  try {
    final rates = await fetchLatestRates();
    await cacheRates(rates);
  } catch (e) {
    // Use cached rates, show warning
  }
}
```

#### 4. **Self-Hosting Option (Future)**
- Deploy Frankfurter on Firebase Cloud Run
- Use custom domain: `https://rates.invtrack.app`
- Full control over uptime and data
- No dependency on third-party service

---

## 🔄 Alternative: ExchangeRate-API

### Pros
- 161 currencies (more than Frankfurter)
- 1,500 requests/month free tier
- Simple API with free tier API key

### Cons
- Requires API key (even for free tier)
- Rate limit: 1,500 requests/month
- Not self-hostable
- Less transparent data source

### When to Use
- If you need more than 33 currencies
- If 1,500 requests/month is sufficient
- If self-hosting is not a priority

---

## ❌ Not Recommended

### Currencylayer, Fixer.io, Open Exchange Rates
**Why Not:**
- Very restrictive free tiers (100-1,000 requests/month)
- Historical data requires paid plan
- API key required
- Not self-hostable
- InvTrack users would quickly hit rate limits

---

## 📈 Usage Estimation for InvTrack

### Scenario: 1,000 Active Users

**Assumptions:**
- Each user opens app 3 times/day
- Exchange rates update once per day per user
- 1,000 users × 1 request/day = **1,000 requests/day**
- **30,000 requests/month**

**Frankfurter:** ✅ No limits - handles easily  
**ExchangeRate-API:** ❌ 1,500/month - insufficient  
**Currencylayer:** ❌ 100/month - completely insufficient

---

## 🎯 Final Recommendation

### **Use Frankfurter API**

**Reasons:**
1. ✅ No rate limits - scales with user growth
2. ✅ No API key - simpler implementation
3. ✅ Self-hostable - future-proof
4. ✅ Covers all InvTrack currencies
5. ✅ Free forever - no surprise costs
6. ✅ Open-source - transparent and trustworthy
7. ✅ Historical data - supports time-series analysis

**Implementation Plan:**
- **Phase 1:** Use public API (`api.frankfurter.dev`)
- **Phase 2:** Cache rates in Firestore (offline-first)
- **Phase 3:** Self-host on Cloud Run (optional, for scale)

---

## 📚 Resources

- **Frankfurter Docs:** https://frankfurter.dev/
- **GitHub:** https://github.com/lineofflight/frankfurter
- **Docker Image:** `lineofflight/frankfurter`
- **License:** MIT (free for commercial use)

---

**Decision:** Use **Frankfurter API** for InvTrack multi-currency support ✅

---

## 🤔 Historical Rates: Do We Need Previous Day Rates?

### **Question:** Does Frankfurter provide previous day rates? Should we use them?

### **Answer: YES to both!**

#### **1. Frankfurter DOES Provide Historical Rates**

```bash
# Get rates for a specific date
GET https://api.frankfurter.dev/v1/2026-02-12

# Response
{
  "base": "EUR",
  "date": "2026-02-12",
  "rates": {
    "USD": 1.05,
    "GBP": 0.83,
    "INR": 87.50
  }
}

# Get time series (range of dates)
GET https://api.frankfurter.dev/v1/2026-01-01..2026-02-13

# Response
{
  "base": "EUR",
  "start_date": "2026-01-01",
  "end_date": "2026-02-13",
  "rates": {
    "2026-01-01": { "USD": 1.04, "GBP": 0.82, "INR": 86.50 },
    "2026-01-02": { "USD": 1.05, "GBP": 0.83, "INR": 87.00 },
    "...": "..."
  }
}
```

**Historical data available:** Since 1999 (25+ years)

---

#### **2. Should We Use Historical Rates? YES!**

### **Why Historical Rates Matter for InvTrack**

InvTrack uses **date-aware XIRR calculations** - each cash flow has a specific date. For accurate multi-currency portfolio returns, we MUST use the exchange rate **on the transaction date**, not today's rate.

### **Example: Why Current Rates Are Wrong**

**Scenario:**
- User invested **$10,000 USD** on **Jan 1, 2024** (rate: 1 USD = 83 INR)
- User's base currency: **INR**
- Today: **Feb 13, 2026** (rate: 1 USD = 85 INR)

**Wrong Approach (Current Rate):**
```dart
// Using today's rate for historical transaction
final investedINR = 10000 * 85; // ₹8,50,000
// WRONG! On Jan 1, 2024, it was actually ₹8,30,000
```

**Correct Approach (Historical Rate):**
```dart
// Using rate on transaction date (Jan 1, 2024)
final investedINR = 10000 * 83; // ₹8,30,000
// CORRECT! This is what the user actually invested in INR terms
```

**Impact on XIRR:**
- Wrong approach: Overstates investment by ₹20,000
- Correct approach: Accurate XIRR calculation
- Difference: Can change XIRR by 2-5% (significant!)

---

### **How InvTrack Currently Works**

From codebase analysis:

```dart
// XIRR calculation uses EXACT transaction dates
final dates = [DateTime(2023, 1, 1), DateTime(2024, 1, 1)];
final amounts = [-100000.0, 110000.0];
final xirr = XirrSolver.calculateXirr(dates, amounts);

// Formula: Σ (Cashflow_i / (1 + XIRR)^((Date_i - Date_0) / 365)) = 0
```

**Key Insight:** InvTrack's XIRR uses **exact dates** for time-weighted returns. For multi-currency, we MUST use **exchange rates on those exact dates**.

---

### **Implementation Strategy: Historical Rates**

#### **Option 1: Fetch Historical Rate on Transaction Date** ⭐ RECOMMENDED

```dart
// When user adds a transaction in foreign currency
Future<void> addTransaction({
  required DateTime date,
  required double amount,
  required String currency,
}) async {
  // 1. Fetch exchange rate for transaction date
  final rate = await _getExchangeRate(
    date: date,
    from: currency,
    to: userBaseCurrency,
  );

  // 2. Store BOTH original amount AND converted amount
  final transaction = CashFlowEntity(
    date: date,
    amount: amount,
    currency: currency,
    exchangeRate: rate,
    convertedAmount: amount * rate,
    baseCurrency: userBaseCurrency,
  );

  // 3. Save to Firestore
  await repository.save(transaction);
}

Future<double> _getExchangeRate({
  required DateTime date,
  required String from,
  required String to,
}) async {
  // Format date as YYYY-MM-DD
  final dateStr = DateFormat('yyyy-MM-dd').format(date);

  // Fetch from Frankfurter
  final response = await http.get(
    Uri.parse('https://api.frankfurter.dev/v1/$dateStr?base=$from&symbols=$to'),
  );

  final data = jsonDecode(response.body);
  return data['rates'][to];
}
```

**Advantages:**
- ✅ Accurate XIRR calculations
- ✅ Historical accuracy preserved
- ✅ No need to recalculate on rate changes
- ✅ Audit trail (know exact rate used)

**Disadvantages:**
- ❌ Requires API call on every transaction (can cache)
- ❌ Slightly more complex implementation

---

#### **Option 2: Use Current Rate + Recalculate Periodically** ❌ NOT RECOMMENDED

```dart
// Use today's rate for all transactions
final rate = await _getCurrentExchangeRate(from, to);
final convertedAmount = amount * rate;
```

**Why NOT Recommended:**
- ❌ Inaccurate XIRR (uses wrong rates for historical transactions)
- ❌ Returns change when rates change (confusing for users)
- ❌ No historical accuracy
- ❌ Violates InvTrack's date-aware calculation principle

---

### **Caching Strategy for Historical Rates**

```dart
// Cache structure in Firestore
users/{userId}/exchangeRates/{date}
{
  "date": "2026-02-13",
  "base": "USD",
  "rates": {
    "EUR": 0.92,
    "GBP": 0.79,
    "INR": 83.25
  },
  "fetchedAt": "2026-02-13T10:30:00Z"
}
```

**Cache Logic:**
1. Check if rate exists in cache for transaction date
2. If exists: Use cached rate
3. If not: Fetch from Frankfurter, cache it, use it
4. Cache never expires (historical rates don't change)

**Benefits:**
- ✅ Reduces API calls (only fetch once per date)
- ✅ Works offline (uses cached rates)
- ✅ Fast (no network call for cached dates)

---

### **Final Recommendation**

**Use Historical Rates (Option 1) with Caching:**

1. **On Transaction Entry:**
   - Fetch exchange rate for transaction date from Frankfurter
   - Cache rate in Firestore
   - Store both original amount AND converted amount in transaction

2. **On XIRR Calculation:**
   - Use pre-converted amounts (already in base currency)
   - No need to fetch rates again
   - Accurate time-weighted returns

3. **On Portfolio Display:**
   - Show original currency + amount
   - Show converted amount in base currency
   - Show exchange rate used (transparency)

**Example UI:**
```
Investment: $10,000 USD
Converted: ₹8,30,000 INR (@ 83.00 on Jan 1, 2024)
```

---

**Updated Decision:** Use **Frankfurter API with Historical Rates** for accurate multi-currency XIRR calculations ✅

