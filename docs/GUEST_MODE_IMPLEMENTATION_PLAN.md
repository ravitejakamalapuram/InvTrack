# Guest Mode Implementation Plan

## Overview
Implement guest mode to allow users to use InvTrack without signing in, with local-only data storage and seamless migration to cloud when they sign in later.

## Current Architecture Analysis

### Authentication Flow
- **Current**: Mandatory Google Sign-In → Firebase Auth → Firestore
- **Issue**: Users must sign in before using the app
- **Onboarding**: Shows "Works Offline, Syncs Online" but requires sign-in first

### Data Storage
- **Current**: All data stored in Firestore at `users/{userId}/...`
- **Collections**: investments, cashflows, goals, archivedInvestments, archivedCashflows, archivedGoals, documents, fireSettings, profile, exchangeRates
- **Offline**: Firestore offline persistence enabled (cache-first)

### Router Logic
```
Onboarding → Sign-In → Home (if authenticated)
```

## Proposed Architecture

### 1. Dual Storage Strategy

#### Local Storage (Guest Mode)
- **Technology**: Hive (NoSQL, fast, offline-first)
- **Location**: App documents directory
- **Structure**: Mirrors Firestore schema
- **User ID**: Generate UUID for guest user (`guest_<uuid>`)

#### Cloud Storage (Signed-In Mode)
- **Technology**: Firestore (existing)
- **Location**: `users/{userId}/...`
- **Migration**: One-time sync from local to cloud

### 2. Repository Pattern Enhancement

#### Current Pattern
```dart
FirestoreInvestmentRepository implements InvestmentRepository
```

#### New Pattern
```dart
abstract class InvestmentRepository {
  // Existing methods
}

class FirestoreInvestmentRepository implements InvestmentRepository {
  // Cloud storage (existing)
}

class HiveInvestmentRepository implements InvestmentRepository {
  // Local storage (new)
}

// ✅ FIXED: Handle AsyncValue states properly
// Provider selects implementation based on auth state
final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final authState = ref.watch(authStateProvider);

  // Handle loading/error states - default to guest mode
  return authState.when(
    data: (user) {
      if (user == null || user.isGuest) {
        return ref.watch(hiveInvestmentRepositoryProvider);
      } else {
        return ref.watch(firestoreInvestmentRepositoryProvider);
      }
    },
    loading: () => ref.watch(hiveInvestmentRepositoryProvider),
    error: (_, __) => ref.watch(hiveInvestmentRepositoryProvider),
  );
});
```

### 3. Authentication Flow Changes

#### New Flow
```
Onboarding → [Skip Sign-In] → Home (Guest Mode)
           → [Sign In] → Home (Cloud Mode)
```

#### Guest User Entity
```dart
class UserEntity {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isGuest; // NEW
  
  // Factory for guest user
  factory UserEntity.guest() {
    return UserEntity(
      id: 'guest_${Uuid().v4()}',
      email: 'guest@local',
      displayName: 'Guest User',
      photoUrl: null,
      isGuest: true,
    );
  }
}
```

### 4. Data Migration Service

#### Migration Trigger
- User signs in while in guest mode
- Prompt: "Migrate your local data to cloud?"

#### Migration Process
1. **Backup**: Export guest data to ZIP (safety)
2. **Upload**: Bulk import to Firestore
3. **Verify**: Check all data migrated
4. **Cleanup**: Delete local Hive data
5. **Switch**: Update auth state to signed-in user

#### Migration Service
```dart
class GuestDataMigrationService {
  Future<MigrationResult> migrateToCloud({
    required String guestUserId,
    required String signedInUserId,
    required MigrationStrategy strategy, // ✅ FIXED: Add required parameter
  }) async {
    // 1. Export guest data for backup
    final guestData = await _exportGuestData(guestUserId);

    // 2. Import to Firestore based on strategy
    // ✅ FIXED: Branch on strategy parameter
    if (strategy == MigrationStrategy.merge) {
      // Merge: Combine guest + cloud data
      await _mergeData(signedInUserId, guestData);
    } else if (strategy == MigrationStrategy.replace) {
      // Replace: Keep guest data, discard cloud
      await _replaceData(signedInUserId, guestData);
    }

    // 3. Verify migration
    final verified = await _verifyMigration(guestData, signedInUserId);

    // 4. Cleanup local data
    if (verified) {
      await _cleanupGuestData(guestUserId);
    }

    return MigrationResult(success: verified);
  }

  Future<void> _mergeData(String userId, GuestData data) async {
    // Append guest data to existing cloud data
    await _importToFirestore(userId, data);
  }

  Future<void> _replaceData(String userId, GuestData data) async {
    // Delete existing cloud data, then import guest data
    await _deleteAllCloudData(userId);
    await _importToFirestore(userId, data);
  }
}
```

## Implementation Details

### Phase 1: Local Storage Setup
- [ ] Add Hive dependency
- [ ] Create Hive adapters for entities
- [ ] Implement HiveInvestmentRepository
- [ ] Implement HiveCashFlowRepository
- [ ] Implement HiveGoalRepository
- [ ] Implement HiveDocumentRepository (local file storage)
- [ ] Implement HiveSettingsRepository

### Phase 2: Authentication Changes
- [ ] Add `isGuest` field to UserEntity
- [ ] Create guest user factory
- [ ] Update authStateProvider to support guest mode
- [ ] Modify router to allow guest access
- [ ] Add "Continue as Guest" button to sign-in screen

### Phase 3: Repository Provider Updates
- [ ] Create repository selector based on auth state
- [ ] Update all repository providers
- [ ] Ensure offline-first behavior for both modes

### Phase 4: Data Migration
- [ ] Create GuestDataMigrationService
- [ ] Build migration UI flow
- [ ] Add migration progress indicator
- [ ] Handle migration errors gracefully

### Phase 5: UI/UX Enhancements
- [ ] Add guest mode indicator in app bar
- [ ] Show "Sign in to sync" prompts
- [ ] Add upgrade to cloud benefits screen
- [ ] Update settings screen for guest mode

## Feature Compatibility Analysis

### ✅ Works in Guest Mode (No Changes)
- **Investments**: Local CRUD operations
- **Cash Flows**: Local CRUD operations
- **Goals**: Local tracking
- **XIRR/MOIC**: Pure calculations
- **Privacy Mode**: Local SharedPreferences
- **Passcode Lock**: Local FlutterSecureStorage
- **Biometrics**: Local authentication
- **Theme Settings**: Local SharedPreferences
- **Sample Data**: Local generation
- **Export**: Works with local data
- **Import**: Works with local data
- **Notifications**: Local scheduling
- **FIRE Calculator**: Pure calculations

### ⚠️ Requires Adaptation
- **Multi-Currency**: ✅ UPDATED - Fetch live rates on first internet connection (even in guest mode), cache locally in Hive, refresh every 24 hours when online, fall back to cached rates when offline, show "estimated" label if rates are >7 days old
- **Documents**: Store in app documents directory (not cloud storage)
- **User Profile**: Store locally (no Firestore sync)

### ❌ Disabled in Guest Mode
- **Cloud Sync**: Not available (by design)
- **Multi-Device Sync**: Not available (by design)
- **Account Deletion**: Not applicable (local data only)

## Security & Privacy Considerations

### Guest Mode Security
- ✅ Passcode lock works (FlutterSecureStorage)
- ✅ Biometrics work (local authentication)
- ✅ Privacy mode works (local settings)
- ✅ Data encrypted at rest (Hive encryption)

### Data Privacy
- ✅ No data sent to cloud in guest mode
- ✅ No analytics with PII (existing rules apply)
- ✅ Local data deleted on app uninstall
- ⚠️ No backup unless user exports manually

## Migration Edge Cases

### Case 1: Guest has data, signs in to existing account
- **Solution**: Prompt to merge or replace
- **Options**:
  - Merge: Combine guest + cloud data
  - Replace: Keep guest data, discard cloud (replace cloud with local)
  - Keep Local: Stay in guest mode

### Case 2: Migration fails mid-process
- **Solution**: Rollback mechanism
- **Backup**: Keep guest data until verified
- **Retry**: Allow manual retry

### Case 3: User signs out after migration
- **Solution**: Stay in cloud mode (data already migrated)
- **Option**: Allow "Download for offline" to create new guest session

## Testing Strategy

### Unit Tests
- [ ] Hive repository CRUD operations
- [ ] Guest user entity creation
- [ ] Migration service logic
- [ ] Repository provider selection

### Integration Tests
- [ ] Guest mode full flow
- [ ] Sign-in from guest mode
- [ ] Data migration end-to-end
- [ ] Feature compatibility in guest mode

### Manual Testing
- [ ] Onboarding → Guest mode
- [ ] Create investments in guest mode
- [ ] Sign in and migrate data
- [ ] Verify data in cloud
- [ ] Test all features in both modes

## Rollout Plan

### Phase 1: Foundation (Week 1)
- Hive setup
- Local repositories
- Guest user entity

### Phase 2: Core Features (Week 2)
- Auth flow changes
- Repository providers
- Basic guest mode

### Phase 3: Migration (Week 3)
- Migration service
- Migration UI
- Error handling

### Phase 4: Polish (Week 4)
- UI/UX enhancements
- Testing
- Documentation

## Success Metrics
- [ ] Users can use app without sign-in
- [ ] All core features work in guest mode
- [ ] Migration success rate >95%
- [ ] No data loss during migration
- [ ] Performance: Local operations <100ms

