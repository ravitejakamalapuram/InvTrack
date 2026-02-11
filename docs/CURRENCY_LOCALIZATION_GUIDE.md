# Currency Localization Guide

## Overview

InvTrack supports 35+ currencies with locale-aware formatting. This guide explains how to properly format currency amounts to respect user locale settings.

## Key Concepts

### Locale-Aware Notation

Different locales use different notation for large numbers:

- **Western locales** (en_US, en_GB, de_DE, etc.): Use K/M notation
  - 100,000 → 100K
  - 1,000,000 → 1M
  - 10,000,000 → 10M

- **Indian locale** (en_IN): Use L/Cr notation
  - 1,00,000 → 1L (1 lakh)
  - 10,00,000 → 10L (10 lakhs)
  - 1,00,00,000 → 1Cr (1 crore)

## Required Utilities

### `formatCompactCurrency()` - ALWAYS USE THIS

Located in `lib/core/utils/currency_utils.dart`

```dart
String formatCompactCurrency(
  double amount, {
  String symbol = '₹',
  String locale = 'en_IN',
  int maxDecimals = 1,
  bool alwaysShowDecimals = false,
})
```

**Parameters:**
- `amount`: The amount to format
- `symbol`: Currency symbol (e.g., '₹', '$', '€')
- `locale`: Locale code (e.g., 'en_IN', 'en_US', 'de_DE')
- `maxDecimals`: Maximum decimal places (default: 1)
- `alwaysShowDecimals`: Always show decimals even for whole numbers

### `formatCompactIndian()` - DEPRECATED ❌

**DO NOT USE** - This function always uses Indian notation regardless of locale.

## Implementation Patterns

### Presentation Layer (Widgets)

Widgets should watch `currencyLocaleProvider` and `currencySymbolProvider`:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final locale = ref.watch(currencyLocaleProvider);
  final symbol = ref.watch(currencySymbolProvider);
  
  return Text(
    formatCompactCurrency(
      investment.currentValue,
      symbol: symbol,
      locale: locale,
    ),
  );
}
```

### Domain Layer (Entities)

Domain entities should accept locale as a method parameter (no provider access):

```dart
// In domain/entities/goal_progress.dart
String getProgressMessage([String symbol = '₹', String locale = 'en_IN']) {
  return '$symbol${_formatAmount(currentAmount, locale)} of $symbol${_formatAmount(targetAmount, locale)}';
}

String _formatAmount(double amount, String locale) {
  return formatCompactCurrency(
    amount,
    symbol: '',  // Symbol added separately
    locale: locale,
  );
}
```

## Common Mistakes

### ❌ Hardcoded Indian Notation

```dart
// WRONG - Always shows L/Cr
formatCompactIndian(amount, symbol: '₹')
```

### ❌ Missing Locale Parameter

```dart
// WRONG - Defaults to en_US
formatCompactCurrency(amount, symbol: '₹')
```

### ❌ Domain Layer Accessing Providers

```dart
// WRONG - Domain can't access providers
class GoalProgress {
  String getMessage() {
    final locale = ref.watch(currencyLocaleProvider);  // ❌
    return formatCompactCurrency(amount, locale: locale);
  }
}
```

### ✅ Correct Approach

```dart
// Presentation layer
final locale = ref.watch(currencyLocaleProvider);
final message = progress.getProgressMessage(currencySymbol, locale);

// Domain layer
String getProgressMessage(String symbol, String locale) {
  return formatCompactCurrency(amount, symbol: symbol, locale: locale);
}
```

## Testing Currency Localization

### Manual Testing

1. Go to Settings → Currency
2. Switch between currencies:
   - USD → Should show K/M notation
   - EUR → Should show K/M notation
   - INR → Should show L/Cr notation
3. Verify all amount displays update correctly

### Unit Testing

```dart
test('formats amount with correct locale notation', () {
  // Western locale
  expect(
    formatCompactCurrency(100000, symbol: '\$', locale: 'en_US'),
    '\$100K',
  );
  
  // Indian locale
  expect(
    formatCompactCurrency(100000, symbol: '₹', locale: 'en_IN'),
    '₹1L',
  );
});
```

## Checklist for New Features

Before submitting PR with currency amounts:

- [ ] All amounts use `formatCompactCurrency()` with locale parameter
- [ ] No direct calls to `formatCompactIndian()` (deprecated)
- [ ] Presentation layer widgets watch `currencyLocaleProvider`
- [ ] Domain entities accept locale as method parameter
- [ ] Tested currency switching (USD → EUR → INR)
- [ ] Compact notation changes correctly (K/M for Western, L/Cr for Indian)

## Supported Currencies

InvTrack supports 35+ currencies including:
- USD, EUR, GBP, INR, JPY, CAD, AUD, CHF, CNY, SGD, HKD, BRL, MXN, ZAR, and more

See `lib/core/utils/locale_detection_service.dart` for the complete list.

