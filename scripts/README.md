# Migration Scripts

## migrate_to_inr.dart

**One-time migration script** to set base currency to INR for all users and update all cashflows/investments to INR currency.

### What it does:

1. **Updates all user profiles:**
   - Sets `currencyCode` to `INR`
   - Sets `currencySymbol` to `₹`
   - Sets `locale` to `en_IN`

2. **Updates all cashflows:**
   - Sets `currency` field to `INR` for all cashflow documents

3. **Updates all investments:**
   - Sets `currency` field to `INR` for all investment documents

### Prerequisites:

- Firebase Admin access (you must be authenticated)
- Dart SDK installed
- All dependencies installed (`flutter pub get`)

### Usage:

```bash
# Run the migration script
dart run scripts/migrate_to_inr.dart
```

### Safety:

- ✅ Script asks for confirmation before running
- ✅ Only updates documents that aren't already in INR
- ✅ Uses batched writes for efficiency
- ✅ Provides detailed progress output
- ⚠️  **Make sure you have a Firestore backup before running!**

### Output:

The script will show:
- Number of users processed
- Number of user profiles updated
- Number of cashflows updated
- Number of investments updated

### Example Output:

```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  INR MIGRATION SCRIPT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
This will update ALL users to use INR as base currency
and set all cashflows/investments to INR currency.

Are you sure you want to continue? (yes/no)
yes

🚀 Starting migration to INR...

📋 Step 1: Fetching all users...
   Found 5 users

👤 Processing user: user123
   ✅ Updated user profile to INR
   ✅ Updated 10 cashflows to INR
   ✅ Updated 5 investments to INR

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

### Rollback:

If you need to rollback, you'll need to restore from your Firestore backup.

### Notes:

- This is a **one-time** migration script
- After running, all users will see amounts in INR
- The script is idempotent (safe to run multiple times)
- Already-migrated data will be skipped

