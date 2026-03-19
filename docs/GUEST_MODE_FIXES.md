# Guest Mode & Account Linking - Comprehensive Fix

## 🐛 Issues Fixed

### 1. **Critical: Account Linking Data Loss Bug**
**Problem**: The "Sign In to Link" button was using `signInWithGoogle()` instead of Firebase's `linkWithCredential()` API, causing:
- ❌ Anonymous user session replaced with new Google session
- ❌ All guest data orphaned (different UID)
- ❌ User loses all investments, goals, and settings

**Root Cause**: `LinkAccountUseCase` was calling `signInWithGoogle()` which creates a NEW user session instead of linking credentials to the EXISTING anonymous session.

**Fix**: Implemented proper Firebase account linking using `linkWithCredential()` API:
- ✅ Preserves anonymous UID
- ✅ Keeps all Firestore data accessible
- ✅ Converts anonymous → Google without data loss

---

### 2. **Navigation Loop Bug**
**Problem**: "Sign In to Link" button navigated to `/auth/signin`, which:
- Triggered auth state listeners
- Caused navigation loops
- Didn't use the proper linking handler

**Fix**: Changed button to call `GoogleSignInHandler` directly instead of navigating to sign-in screen.

---

### 3. **Missing Error Handling**
**Problem**: No handling for:
- User cancels Google Sign-In
- Google account already exists (credential-already-in-use)
- Invalid credentials

**Fix**: Added comprehensive error handling with user-friendly messages and proper flow for each case.

---

## 📝 Files Modified

### 1. **Domain Layer** (Business Logic)

#### `lib/features/auth/domain/repositories/auth_repository.dart`
- ✅ Added `linkAnonymousToGoogle()` method to interface
- Documents that this preserves UID and data

#### `lib/features/auth/domain/usecases/link_account_usecase.dart`
- ✅ Changed from `signInWithGoogle()` to `linkAnonymousToGoogle()`
- ✅ Added `LinkAccountCancelled` result type
- ✅ Improved error handling with `AuthException` types
- Documents that this uses Firebase `linkWithCredential()` API

---

### 2. **Data Layer** (Firebase Implementation)

#### `lib/features/auth/data/repositories/firebase_auth_repository.dart`
- ✅ Implemented `linkAnonymousToGoogle()` method
- Uses Firebase `currentUser.linkWithCredential(credential)`
- Handles all error cases:
  - `credential-already-in-use` → Shows backup & merge dialog
  - `provider-already-linked` → User-friendly message
  - `invalid-credential` → Retry prompt
  - User cancellation → Silent (no error)
- Preserves anonymous UID throughout the process
- Cleans up Google Sign-In state on error

---

### 3. **Presentation Layer** (UI)

#### `lib/features/auth/presentation/handlers/google_sign_in_handler.dart`
- ✅ Added `_handleCancelled()` method
- Updated switch statement to handle `LinkAccountCancelled` case
- No error message shown when user cancels (intentional action)

#### `lib/features/settings/presentation/widgets/user_profile_card.dart`
- ✅ Changed "Sign In to Link" button from `context.go('/auth/signin')` to calling `GoogleSignInHandler`
- Removed unused `go_router` import
- Button now triggers proper account linking flow

---

## 🔄 Account Linking Flow (Fixed)

### **Before (Broken)**:
```
1. User taps "Sign In to Link"
2. Navigate to /auth/signin
3. Call signInWithGoogle()
4. ❌ Creates NEW user session (new UID)
5. ❌ Guest data orphaned at old UID
6. ❌ User loses all data
```

### **After (Fixed)**:
```
1. User taps "Sign In to Link"
2. Call GoogleSignInHandler.handleSignIn()
3. Call LinkAccountUseCase.execute()
4. Call AuthRepository.linkAnonymousToGoogle()
5. Firebase: currentUser.linkWithCredential(googleCredential)
6. ✅ Same UID preserved
7. ✅ All Firestore data remains accessible
8. ✅ User now has Google account with all guest data
```

---

## 🎯 Error Handling Matrix

| Error Case | User Message | Action |
|------------|--------------|--------|
| **Success** | "Account linked successfully!" | Green snackbar, data preserved |
| **User Cancels** | (none) | Silent, no error shown |
| **Google Account Exists** | Shows backup & merge dialog | Create ZIP backup, sign in to existing account, offer import |
| **Already Linked** | "Account is already linked to Google" | Info message |
| **Invalid Credential** | "Invalid Google credentials. Please try again." | Retry prompt |
| **Network Error** | "Connection error. Please try again." | Retry prompt |
| **Other Errors** | "Linking failed: [reason]" | Error snackbar with details |

---

## ✅ Testing Checklist

### Manual Testing Required:
- [ ] **Happy Path**: Guest user links to new Google account
  - Verify UID stays the same
  - Verify all investments/goals/settings preserved
  - Verify user can sign out and sign back in with Google
  
- [ ] **Google Account Exists**: Guest user tries to link to existing Google account
  - Verify backup & merge dialog appears
  - Verify ZIP backup created
  - Verify sign-in to existing account works
  - Verify import option offered

- [ ] **User Cancels**: Guest user cancels Google Sign-In
  - Verify no error message shown
  - Verify user remains in guest mode
  - Verify no data loss

- [ ] **Network Error**: Test with airplane mode
  - Verify user-friendly error message
  - Verify retry works when network restored

---

## 🔐 Security & Data Integrity

### UID Preservation
- ✅ Firebase `linkWithCredential()` preserves the anonymous UID
- ✅ All Firestore data at `users/{anonymousUID}/` remains accessible
- ✅ No data migration needed

### Firestore Security Rules
```javascript
// Already correct - rules check request.auth.uid
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}
```
Since UID is preserved, security rules continue to work without changes.

---

## 📚 Related Documentation

- **Architecture**: `docs/ANONYMOUS_AUTH_GUEST_MODE.md`
- **Firebase Docs**: [Link Anonymous Accounts](https://firebase.google.com/docs/auth/android/anonymous-auth#convert-an-anonymous-account-to-a-permanent-account)
- **InvTrack Rules**: `.augment/rules/invtrack_rules.md` (Rule 21: Multi-Currency Compliance)

---

## 🚀 Deployment Notes

### Firebase Console Configuration
**REQUIRED**: Anonymous Authentication must be enabled in Firebase Console:
1. Go to Firebase Console → Authentication → Sign-in method
2. Enable "Anonymous" provider
3. Save

Without this, guest mode will fail with `admin-restricted-operation` error.

### No Breaking Changes
- ✅ Existing users unaffected
- ✅ No database migration needed
- ✅ No Firestore rule changes needed
- ✅ Backward compatible

---

**Status**: ✅ All fixes implemented and tested with `flutter analyze` (0 errors)

