---
type: "always_apply"
---

# Security Rules – InvTrack

These rules protect user data and prevent security vulnerabilities.

---

## SEC RULE 1: SENSITIVE DATA LOGGING
NEVER log:
- Passwords or tokens
- API keys or secrets
- User PII (email, phone, full name)
- Financial data (account numbers, balances)
- Document contents
- Authentication states with user details

```dart
// ✅ Safe logging
debugPrint('Investment created: ${investment.id}');

// ❌ Dangerous logging
debugPrint('User data: $userEmail, token: $authToken');
```

---

## SEC RULE 2: LOCAL STORAGE SECURITY
Use appropriate storage for data sensitivity:

| Data Type | Storage | Example |
|-----------|---------|---------|
| Preferences | SharedPreferences | Theme mode, locale |
| Sensitive tokens | FlutterSecureStorage | Auth tokens, encryption keys |
| User data | Firestore (encrypted at rest) | Investments, goals |
| Temp files | App temp directory | Export files (auto-deleted) |

```dart
// ✅ Secure storage for sensitive data
final secureStorage = FlutterSecureStorage();
await secureStorage.write(key: 'auth_token', value: token);

// ❌ Never store sensitive data in SharedPreferences
prefs.setString('auth_token', token); // INSECURE!
```

---

## SEC RULE 3: INPUT VALIDATION
Validate ALL user inputs:
```dart
// ✅ Validate before processing
String sanitizeName(String input) {
  if (input.isEmpty) throw ValidationException('Name required');
  if (input.length > 100) throw ValidationException('Name too long');
  return input.trim();
}

// Validate numeric inputs
double parseAmount(String input) {
  final amount = double.tryParse(input);
  if (amount == null) throw ValidationException('Invalid amount');
  if (amount < 0) throw ValidationException('Amount must be positive');
  if (amount > 999999999) throw ValidationException('Amount too large');
  return amount;
}
```

---

## SEC RULE 4: AUTHENTICATION CHECKS
Always verify authentication before data operations:
```dart
// ✅ Check auth state in repository
final userId = _auth.currentUser?.uid;
if (userId == null) {
  throw UnauthenticatedException();
}

// ✅ Use auth-aware providers
final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final userId = ref.watch(authStateProvider).value?.uid;
  if (userId == null) throw StateError('Not authenticated');
  return FirestoreInvestmentRepository(ref.watch(firestoreProvider), userId);
});
```

---

## SEC RULE 5: FIRESTORE SECURITY RULES
All collections MUST have security rules in `firestore.rules`:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User can only access their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

Test rules with Firebase Emulator before deployment.

---

## SEC RULE 6: DATA EXPORT SECURITY
When exporting user data:
- Use encrypted ZIP when containing sensitive data
- Clear temp files after sharing
- Don't include authentication tokens
- Warn user about data sensitivity
- Use secure share intents

```dart
// ✅ Clean up after export
try {
  await shareFile(exportPath);
} finally {
  await File(exportPath).delete();
}
```

---

## SEC RULE 7: BIOMETRIC AUTHENTICATION
For app lock feature:
- Use `local_auth` package correctly
- Handle biometric unavailable gracefully
- Provide PIN fallback
- Don't store biometric data locally
- Re-authenticate for sensitive operations

---

## SEC RULE 8: NETWORK SECURITY
- All API calls over HTTPS only
- Validate SSL certificates
- Don't expose API keys in client code
- Use Firebase App Check for API protection
- Handle network errors without exposing internals

---

## SEC RULE 9: ERROR HANDLING SECURITY
User-facing errors must NOT reveal:
- Stack traces
- Internal paths
- Database structure
- API endpoints
- Authentication details

```dart
// ✅ Safe error message
catch (e) {
  showError('Something went wrong. Please try again.');
  CrashlyticsService().recordError(e, stack); // Log internally
}

// ❌ Dangerous error message
catch (e) {
  showError('Error: $e'); // May expose internals
}
```

---

## SEC RULE 10: DEPENDENCY SECURITY
- Audit dependencies for known vulnerabilities
- Keep packages updated for security patches
- Review package permissions (especially native)
- Avoid packages with excessive permissions
- Check package source code for suspicious behavior

---

## SEC RULE 11: DEBUG MODE GUARDS
Ensure debug features are stripped in release:
```dart
// ✅ Protected debug code
if (kDebugMode) {
  debugPrint('Sensitive debug info');
  // Debug-only features
}

// ✅ Assert for debug-only checks
assert(() {
  // Expensive validation only in debug
  return true;
}());
```

---

## SEC RULE 12: DATA DELETION
When user deletes account:
- Delete ALL user data from Firestore
- Clear local storage
- Clear secure storage
- Clear cached files
- Revoke authentication tokens
- Confirm deletion is complete

Test deletion flow thoroughly to prevent data leaks.

