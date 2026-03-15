# INR Migration Guide

## Overview

This guide explains how to migrate all users to INR (Indian Rupees) as the base currency.

## What Will Happen

The migration script will:

1. **Update ALL user profiles:**
   - `currencyCode`: → `INR`
   - `currencySymbol`: → `₹`
   - `locale`: → `en_IN`

2. **Update ALL cashflows:**
   - `currency` field → `INR`

3. **Update ALL investments:**
   - `currency` field → `INR`

## Before You Run

### ⚠️ CRITICAL: Create a Firestore Backup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Firestore Database** → **Backups**
4. Click **Create Backup**
5. Wait for backup to complete

### Verify Your Environment

```bash
# Make sure you're in the project directory
cd "$(git rev-parse --show-toplevel)"

# Install dependencies
flutter pub get

# Verify Firebase is configured
flutter run --release  # Should connect to Firebase
```

## Running the Migration

### Step 1: Review the Script

```bash
# View the script
cat scripts/migrate_to_inr.dart
```

### Step 2: Run the Migration

**Important:** This script uses FlutterFire plugins (`firebase_core`, `cloud_firestore`) which require a Flutter runtime environment.

#### Option A: Using Flutter Runtime (Recommended for One-Time Migration)

```bash
# Run the migration script with Flutter runtime
flutter run --target=scripts/migrate_to_inr.dart
```

**Why Flutter runtime?**
- FlutterFire plugins require Flutter's platform channels
- Simple for one-time migrations (no additional setup)
- Uses existing Firebase configuration from the app

#### Option B: Server-Side Alternative (For Headless Environments)

If you need to run this in a headless server environment without Flutter:

1. **Use Firebase Admin SDK** (Node.js/Python/Go):
   - Rewrite the script in your preferred server language
   - Use Firebase Admin SDK for direct Firestore access
   - Requires service account credentials (JSON key file)
   - Example: `firebase-admin` (Node.js) or `firebase-admin-python`

2. **Use Firestore REST API**:
   - Rewrite using Dart's `http` package
   - Authenticate with service account or OAuth2
   - More complex but doesn't require Flutter runtime

**For this one-time migration, Option A (Flutter runtime) is recommended for simplicity.**

### Step 3: Confirm

The script will ask for confirmation:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  INR MIGRATION SCRIPT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
This will update ALL users to use INR as base currency
and set all cashflows/investments to INR currency.

Are you sure you want to continue? (yes/no)
```

Type `yes` and press Enter to proceed.

### Step 4: Monitor Progress

The script will show detailed progress:

```
🚀 Starting migration to INR...

📋 Step 1: Fetching all users...
   Found 5 users

👤 Processing user: abc123
   ✅ Updated user profile to INR
   ✅ Updated 10 cashflows to INR
   ✅ Updated 5 investments to INR

👤 Processing user: def456
   ⏭️  User already using INR
   ⏭️  All cashflows already in INR
   ⏭️  All investments already in INR

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Migration completed successfully!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Summary:
   • User profiles updated: 5
   • Cashflows updated: 50
   • Investments updated: 25
   • Total users processed: 5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## After Migration

### Verify the Changes

1. **Open the app**
2. **Check user settings:**
   - Currency should show `₹ Indian Rupee (INR)`
3. **Check investments:**
   - All amounts should display in INR
4. **Check cashflows:**
   - All amounts should display in INR

### If Something Goes Wrong

1. **Restore from backup:**
   - Go to Firebase Console → Firestore → Backups
   - Select your backup
   - Click **Restore**

2. **Contact support** if you need help

## Safety Features

✅ **Idempotent:** Safe to run multiple times (skips already-migrated data)
✅ **Confirmation required:** Won't run without explicit "yes"
✅ **Detailed logging:** Shows exactly what's being updated
✅ **Batched writes:** Efficient and atomic updates
✅ **Error handling:** Stops on errors with clear messages

## Technical Details

### Collections Updated

- `users/{userId}` - User profile documents
- `users/{userId}/cashflows/{cashflowId}` - All cashflow documents
- `users/{userId}/investments/{investmentId}` - All investment documents

### Fields Updated

**User Profile:**
```json
{
  "currencyCode": "INR",
  "currencySymbol": "₹",
  "locale": "en_IN"
}
```

**Cashflows & Investments:**
```json
{
  "currency": "INR"
}
```

## Troubleshooting

### Error: "Firebase not initialized"

```bash
# Make sure Firebase is configured
flutter pub get
```

### Error: "Permission denied"

- Make sure you're authenticated with Firebase
- Check Firestore security rules allow admin access

### Script hangs or times out

- Check your internet connection
- Verify Firebase project is accessible
- Try running again (script is idempotent)

## Questions?

If you have any questions or issues, check the logs carefully. The script provides detailed output for debugging.

