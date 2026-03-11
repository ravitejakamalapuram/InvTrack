# Guest Mode Implications & Compatibility Analysis

## 1. Feature Compatibility Matrix

### ✅ Fully Compatible (No Changes Required)

| Feature | Guest Mode | Signed-In Mode | Notes |
|---------|-----------|----------------|-------|
| **Investments CRUD** | ✅ Local | ✅ Cloud | Same UI, different storage |
| **Cash Flows CRUD** | ✅ Local | ✅ Cloud | Same UI, different storage |
| **Goals Tracking** | ✅ Local | ✅ Cloud | Same UI, different storage |
| **XIRR Calculation** | ✅ | ✅ | Pure calculation, no storage dependency |
| **MOIC Calculation** | ✅ | ✅ | Pure calculation, no storage dependency |
| **Privacy Mode** | ✅ | ✅ | Uses SharedPreferences (local) |
| **Passcode Lock** | ✅ | ✅ | Uses FlutterSecureStorage (local) |
| **Biometric Auth** | ✅ | ✅ | Uses local authentication |
| **Theme Settings** | ✅ | ✅ | Uses SharedPreferences (local) |
| **Date Format** | ✅ | ✅ | Uses SharedPreferences (local) |
| **Sample Data** | ✅ | ✅ | Generated locally |
| **CSV Export** | ✅ | ✅ | Exports local/cloud data |
| **CSV Import** | ✅ | ✅ | Imports to local/cloud storage |
| **ZIP Export** | ✅ | ✅ | Exports local/cloud data |
| **ZIP Import** | ✅ | ✅ | Imports to local/cloud storage |
| **Notifications** | ✅ | ✅ | Local scheduling |
| **FIRE Calculator** | ✅ | ✅ | Pure calculation |
| **Analytics** | ✅ | ✅ | Anonymous tracking (no PII) |

### ⚠️ Requires Adaptation

| Feature | Guest Mode | Signed-In Mode | Required Changes |
|---------|-----------|----------------|------------------|
| **Multi-Currency** | ⚠️ Cached rates | ✅ Live rates | Cache default exchange rates locally |
| **Documents** | ⚠️ Local files | ✅ Cloud storage | Store in app documents directory |
| **User Profile** | ⚠️ Local only | ✅ Firestore sync | Store in Hive instead of Firestore |
| **Exchange Rates** | ⚠️ Default rates | ✅ API rates | Use fallback rates, show "estimated" label |

### ❌ Disabled in Guest Mode

| Feature | Guest Mode | Signed-In Mode | Reason |
|---------|-----------|----------------|--------|
| **Cloud Sync** | ❌ | ✅ | No Firebase Auth |
| **Multi-Device Sync** | ❌ | ✅ | No cloud storage |
| **Account Deletion** | ❌ | ✅ | No account to delete |
| **Re-authentication** | ❌ | ✅ | No Firebase Auth |

## 2. Data Lifecycle Implications

### 2.1 Guest Mode Data Lifecycle

```
User starts app → Guest mode → Local data created
                                      ↓
                              User continues using
                                      ↓
                              ┌──────┴──────┐
                              ↓             ↓
                        Sign In      Continue Guest
                              ↓             ↓
                        Migrate Data   Data stays local
                              ↓             ↓
                        Cloud Mode    App uninstall
                              ↓             ↓
                        Data synced   Data deleted
```

### 2.2 Data Deletion Scenarios

#### Scenario 1: Guest uninstalls app
- **Result**: All local data deleted (no backup)
- **Mitigation**: Show warning before uninstall (if possible)
- **Best Practice**: Encourage export before uninstall

#### Scenario 2: Guest signs in and migrates
- **Result**: Data moved to cloud, local data deleted
- **Backup**: ZIP backup created before migration
- **Rollback**: Can restore from backup if migration fails

#### Scenario 3: Guest signs in but chooses not to migrate
- **Result**: Guest data stays local, cloud data separate
- **Option**: Allow manual export/import later

### 2.3 Data Persistence

| Storage Type | Guest Mode | Signed-In Mode |
|--------------|-----------|----------------|
| **Investments** | Hive (local) | Firestore (cloud) |
| **Cash Flows** | Hive (local) | Firestore (cloud) |
| **Goals** | Hive (local) | Firestore (cloud) |
| **Documents** | App docs dir | Firebase Storage |
| **Settings** | SharedPreferences | SharedPreferences + Firestore |
| **Exchange Rates** | Hive (cached) | Firestore (cached) |

## 3. Security & Privacy Implications

### 3.1 Security Features

| Feature | Guest Mode | Signed-In Mode | Implementation |
|---------|-----------|----------------|----------------|
| **Passcode Lock** | ✅ Works | ✅ Works | FlutterSecureStorage (local) |
| **Biometric Auth** | ✅ Works | ✅ Works | Local authentication |
| **Data Encryption** | ✅ Hive encryption | ✅ Firestore encryption | Both encrypted at rest |
| **Privacy Mode** | ✅ Works | ✅ Works | SharedPreferences (local) |

### 3.2 Privacy Considerations

#### Guest Mode Privacy Benefits
- ✅ No data sent to cloud
- ✅ No account required
- ✅ No email/phone collection
- ✅ Complete local control

#### Guest Mode Privacy Risks
- ⚠️ No backup if device lost
- ⚠️ Data deleted on app uninstall
- ⚠️ No multi-device access

### 3.3 GDPR Compliance

| Requirement | Guest Mode | Signed-In Mode |
|-------------|-----------|----------------|
| **Data Minimization** | ✅ No PII collected | ✅ Only email from Google |
| **Right to Access** | ✅ Export feature | ✅ Export feature |
| **Right to Erasure** | ✅ Uninstall app | ✅ Delete account |
| **Data Portability** | ✅ CSV/ZIP export | ✅ CSV/ZIP export |
| **Consent** | ✅ No consent needed | ✅ Google Sign-In consent |

## 4. Performance Implications

### 4.1 Storage Performance

⚠️ **Note: Performance numbers are estimated/target values pending validation by storage-level benchmarks**

| Operation | Guest Mode (Hive) | Signed-In Mode (Firestore) |
|-----------|-------------------|----------------------------|
| **Read** | <10ms (local) | 50-200ms (cache) / 200-500ms (network) |
| **Write** | <10ms (local) | 50-200ms (cache) / 200-500ms (network) |
| **Query** | <20ms (local) | 100-300ms (cache) / 300-800ms (network) |
| **Bulk Import** | <100ms (local) | 1-5s (network) |

These values will be validated with dedicated low-level benchmarks in `integration_test/performance/` during Phase 5 (Testing & Polish).

### 4.2 App Size Impact

| Component | Size Impact |
|-----------|-------------|
| **Hive Package** | +500KB |
| **Hive Adapters** | +50KB |
| **Migration Service** | +30KB |
| **Total Impact** | ~600KB |

### 4.3 Memory Impact

| Component | Memory Impact |
|-----------|---------------|
| **Hive Boxes** | ~5-10MB (for 1000 investments) |
| **Firestore Cache** | ~10-20MB (for 1000 investments) |
| **Dual Mode** | No significant increase (only one active) |

## 5. User Experience Implications

### 5.1 Onboarding Flow Changes

#### Current Flow
```
Onboarding → Sign-In (mandatory) → Home
```

#### New Flow
```
Onboarding → [Continue as Guest] → Home (Guest Mode)
           → [Sign In with Google] → Home (Cloud Mode)
```

### 5.2 Guest Mode Indicators

#### App Bar Indicator
```
┌─────────────────────────────┐
│ 🔒 Guest Mode  [Sign In]    │
└─────────────────────────────┘
```

#### Settings Screen
```
┌─────────────────────────────┐
│ Account                     │
│ ├─ Guest User              │
│ ├─ Sign in to sync         │
│ └─ [Sign In with Google]   │
└─────────────────────────────┘
```

### 5.3 Migration Prompts

#### Sign-In Prompt
```
┌─────────────────────────────┐
│ Sign in to sync your data   │
│                             │
│ • Backup to cloud           │
│ • Access from any device    │
│ • Never lose your data      │
│                             │
│ [Sign In] [Maybe Later]     │
└─────────────────────────────┘
```

#### Migration Prompt
```
┌─────────────────────────────┐
│ Migrate your data to cloud? │
│                             │
│ You have 15 investments     │
│ and 3 goals locally.        │
│                             │
│ [Merge with Cloud]          │
│ [Replace Cloud Data]        │
│ [Keep Separate]             │
└─────────────────────────────┘
```

## 6. Analytics Implications

### 6.1 Guest Mode Analytics

| Event | Guest Mode | Signed-In Mode |
|-------|-----------|----------------|
| **User ID** | Anonymous guest ID | Firebase UID |
| **Session Tracking** | Local session ID | Firebase session |
| **Feature Usage** | ✅ Tracked | ✅ Tracked |
| **Crash Reports** | ✅ Anonymous | ✅ With user context |

### 6.2 Migration Analytics

| Event | Parameters |
|-------|-----------|
| `guest_mode_started` | `timestamp` |
| `guest_to_cloud_migration_started` | `strategy`, `investment_count`, `goal_count` |
| `guest_to_cloud_migration_completed` | `duration_ms`, `success`, `items_migrated` |
| `guest_to_cloud_migration_failed` | `error_type`, `error_message` |

## 7. Testing Implications

### 7.1 Test Coverage Requirements

| Test Type | Guest Mode | Signed-In Mode | Migration |
|-----------|-----------|----------------|-----------|
| **Unit Tests** | ✅ Required | ✅ Existing | ✅ Required |
| **Integration Tests** | ✅ Required | ✅ Existing | ✅ Required |
| **E2E Tests** | ✅ Required | ✅ Existing | ✅ Required |
| **Performance Tests** | ✅ Required | ✅ Existing | ⚠️ Optional |

### 7.2 Test Scenarios

#### Guest Mode Tests
- [ ] Create investment in guest mode
- [ ] Add cash flows in guest mode
- [ ] Create goals in guest mode
- [ ] Export data in guest mode
- [ ] Import data in guest mode
- [ ] Use all features in guest mode

#### Migration Tests
- [ ] Migrate empty guest data
- [ ] Migrate guest data to empty cloud
- [ ] Merge guest data with existing cloud data
- [ ] Replace cloud data with guest data
- [ ] Handle migration failure
- [ ] Rollback on migration error

#### Edge Case Tests
- [ ] App killed during migration
- [ ] Network lost during migration
- [ ] Insufficient storage during migration
- [ ] Duplicate data handling
- [ ] Large dataset migration (1000+ items)

## 8. Maintenance Implications

### 8.1 Code Maintenance

| Component | Complexity | Maintenance Effort |
|-----------|-----------|-------------------|
| **Hive Repositories** | Medium | Medium (parallel to Firestore) |
| **Migration Service** | High | Low (one-time use per user) |
| **Repository Providers** | Low | Low (simple selection logic) |
| **UI Changes** | Low | Low (minimal changes) |

### 8.2 Schema Evolution

#### Hive Schema Changes
- Requires Hive adapter updates
- Migration scripts for existing guest users
- Version tracking in Hive boxes

#### Firestore Schema Changes
- Existing migration logic applies
- Guest data migrated to latest schema

## 9. Rollout Strategy

### 9.1 Phased Rollout

#### Phase 1: Internal Testing (Week 1)
- [ ] Hive setup and repositories
- [ ] Guest mode basic flow
- [ ] Internal team testing

#### Phase 2: Beta Testing (Week 2)
- [ ] Migration service
- [ ] Beta user testing
- [ ] Bug fixes

#### Phase 3: Gradual Rollout (Week 3)
- [ ] 10% of new users
- [ ] Monitor analytics
- [ ] Adjust based on feedback

#### Phase 4: Full Rollout (Week 4)
- [ ] 100% of new users
- [ ] Existing users see "Continue as Guest" option
- [ ] Monitor migration success rate

### 9.2 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Guest Mode Adoption** | >30% of new users | Analytics |
| **Migration Success Rate** | >95% | Analytics |
| **Data Loss Rate** | <0.1% | Error tracking |
| **Performance** | <100ms local ops | Performance monitoring |
| **User Satisfaction** | >4.5/5 | App store reviews |

## 10. Rollback Plan

### 10.1 Rollback Triggers
- Migration success rate <90%
- Data loss reports >0.5%
- Critical bugs affecting >5% users
- Performance degradation >20%

### 10.2 Rollback Process
1. Disable guest mode in app config
2. Force all new users to sign in
3. Existing guest users can continue
4. Provide migration path for existing guests
5. Fix issues and re-enable

### 10.3 Data Recovery
- Guest data backed up before migration
- ZIP export available for manual recovery
- Support team can assist with data recovery

