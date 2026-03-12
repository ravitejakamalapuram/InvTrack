# Guest Mode Implementation Summary

## Executive Summary

This document provides a comprehensive plan for implementing **Guest Mode** in InvTrack, allowing users to use the app without signing in while maintaining full feature compatibility and providing a seamless migration path to cloud storage.

## Key Documents

1. **[GUEST_MODE_IMPLEMENTATION_PLAN.md](./GUEST_MODE_IMPLEMENTATION_PLAN.md)** - High-level architecture and implementation phases
2. **[GUEST_MODE_TECHNICAL_SPEC.md](./GUEST_MODE_TECHNICAL_SPEC.md)** - Detailed technical specifications and code examples
3. **[GUEST_MODE_IMPLICATIONS.md](./GUEST_MODE_IMPLICATIONS.md)** - Feature compatibility, security, performance, and testing implications
4. **[GUEST_MODE_UI_UX_SPEC.md](./GUEST_MODE_UI_UX_SPEC.md)** - Complete UI/UX specifications with mockups

## What is Guest Mode?

Guest Mode allows users to:
- ✅ Use InvTrack **without signing in**
- ✅ Store all data **locally on device** (Hive database)
- ✅ Access **all features** (investments, goals, FIRE calculator, etc.)
- ✅ **Migrate to cloud** later when they sign in
- ✅ **Export data** anytime (CSV/ZIP)

## Why Guest Mode?

### Current Pain Point
- Users must sign in with Google before using the app
- Onboarding says "Works Offline, Syncs Online" but requires sign-in first
- Some users want to try the app before committing to sign-in

### Benefits
1. **Lower Barrier to Entry**: Users can start immediately
2. **Privacy**: No data sent to cloud unless user chooses
3. **Offline-First**: True offline experience
4. **Flexibility**: Users choose when to upgrade to cloud

## Architecture Overview

### Dual Storage Strategy

```
┌─────────────────────────────────────────────────────┐
│                   InvTrack App                      │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐         ┌──────────────┐        │
│  │ Guest Mode   │         │ Signed-In    │        │
│  │              │         │ Mode         │        │
│  │ Hive DB      │ ──────> │ Firestore    │        │
│  │ (Local)      │ Migrate │ (Cloud)      │        │
│  └──────────────┘         └──────────────┘        │
│                                                     │
│  Repository Pattern selects storage based on auth  │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Repository Pattern

```dart
// Abstract interface (unchanged)
abstract class InvestmentRepository {
  Stream<List<InvestmentEntity>> watchAllInvestments();
  Future<void> createInvestment(InvestmentEntity investment);
  // ... other methods
}

// Hive implementation (NEW)
class HiveInvestmentRepository implements InvestmentRepository {
  // Local storage using Hive
}

// Firestore implementation (EXISTING)
class FirestoreInvestmentRepository implements InvestmentRepository {
  // Cloud storage using Firestore
}

// ✅ FIXED: Handle AsyncValue states properly
// Provider selects implementation (NEW)
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

## Feature Compatibility

### ✅ Fully Compatible (No Changes)
- Investments CRUD
- Cash Flows CRUD
- Goals Tracking
- XIRR/MOIC Calculations
- Privacy Mode
- Passcode Lock
- Biometric Auth
- Theme Settings
- Sample Data
- Export/Import (CSV/ZIP)
- Notifications
- FIRE Calculator
- Analytics (anonymous)

### ⚠️ Requires Adaptation
- **Multi-Currency**: Use cached exchange rates (no live API)
- **Documents**: Store in app documents directory (not Firebase Storage)
- **User Profile**: Store in Hive (not Firestore)

### ❌ Disabled in Guest Mode
- Cloud Sync (by design)
- Multi-Device Sync (by design)
- Account Deletion (no account to delete)

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Add Hive dependency to `pubspec.yaml`
- [ ] Create Hive type adapters for all entities
- [ ] Implement `HiveInvestmentRepository`
- [ ] Implement `HiveCashFlowRepository`
- [ ] Implement `HiveGoalRepository`
- [ ] Implement `HiveDocumentRepository`
- [ ] Implement `HiveSettingsRepository`
- [ ] Create repository provider selection logic

### Phase 2: Authentication (Week 2)
- [ ] Add `isGuest` field to `UserEntity`
- [ ] Create `UserEntity.guest()` factory
- [ ] Implement `GuestAuthRepository`
- [ ] Update `authStateProvider` to support guest mode
- [ ] Modify router to allow guest access
- [ ] Add "Continue as Guest" button to sign-in screen
- [ ] Add guest mode indicator to app bar

### Phase 3: Migration (Week 3)
- [ ] Create `GuestDataMigrationService`
- [ ] Implement migration strategies (merge/replace)
- [ ] Build migration UI flow
- [ ] Add migration progress indicator
- [ ] Handle migration errors gracefully
- [ ] Create backup before migration
- [ ] Verify migration success
- [ ] Cleanup guest data after migration

### Phase 4: UI/UX (Week 4)
- [ ] Add guest mode indicators throughout app
- [ ] Create periodic backup/export reminders (after data entry, monthly)
- [ ] Update settings screen for guest mode
- [ ] Add migration flow screens
- [ ] Update Help & FAQ with guest mode info
- [ ] Add localization strings (ARB files)
- [ ] Implement animations and transitions

### Phase 5: Testing & Polish (Week 5)
- [ ] Unit tests for Hive repositories
- [ ] Integration tests for guest mode flows
- [ ] E2E tests for migration
- [ ] Performance testing (local vs cloud)
- [ ] Edge case testing (network errors, storage errors)
- [ ] Beta testing with real users
- [ ] Bug fixes and polish

## Migration Flow

### User Journey

```
1. User in Guest Mode
   ↓
2. Taps "Sign In" button
   ↓
3. Google Sign-In flow
   ↓
4. Migration prompt appears
   ├─ Merge with Cloud Data
   ├─ Replace Cloud Data
   └─ Keep Separate (export guest data)
   ↓
5. Migration progress (with backup)
   ↓
6. Migration success/failure
   ↓
7. User now in Cloud Mode
```

### Migration Strategies

#### 1. Merge (Recommended)
- Combines guest data with existing cloud data
- No data loss
- Handles duplicates intelligently

#### 2. Replace
- Deletes cloud data
- Uploads guest data
- Use when cloud data is outdated

#### 3. Keep Separate
- Exports guest data to ZIP
- Starts fresh with cloud
- User can import later if needed

## Security & Privacy

### Guest Mode Security
- ✅ Passcode lock works (FlutterSecureStorage)
- ✅ Biometric auth works (local authentication)
- ✅ Privacy mode works (SharedPreferences)
- ✅ Data encrypted at rest (Hive encryption)

### Privacy Benefits
- ✅ No data sent to cloud
- ✅ No account required
- ✅ No email/phone collection
- ✅ Complete local control

### Privacy Risks
- ⚠️ No backup if device lost
- ⚠️ Data deleted on app uninstall
- ⚠️ No multi-device access

## Performance Impact

### Storage Performance
⚠️ **Note: Performance numbers are estimated/target values pending validation**

These values will be validated with dedicated low-level benchmarks in `integration_test/performance/` during Phase 5 (Testing & Polish).

| Operation | Guest Mode | Signed-In Mode |
|-----------|-----------|----------------|
| Read | <10ms | 50-500ms |
| Write | <10ms | 50-500ms |
| Query | <20ms | 100-800ms |

### App Size Impact
- Hive package: +500KB
- Hive adapters: +50KB
- Migration service: +30KB
- **Total: ~600KB**

## Testing Strategy

### Unit Tests
- Hive repository CRUD operations
- Guest user entity creation
- Migration service logic
- Repository provider selection

### Integration Tests
- Guest mode full flow
- Sign-in from guest mode
- Data migration end-to-end
- Feature compatibility in guest mode

### E2E Tests
- Onboarding → Guest mode → Create data → Sign in → Migrate
- Migration failure scenarios
- Large dataset migration (1000+ items)

## Rollout Plan

### Phase 1: Internal Testing (10% of team)
- Test all features in guest mode
- Test migration flows
- Identify and fix bugs

### Phase 2: Beta Testing (100 users)
- Invite beta testers
- Monitor analytics
- Gather feedback

### Phase 3: Gradual Rollout (10% → 50% → 100%)
- Start with 10% of new users
- Monitor migration success rate
- Increase to 50% if successful
- Full rollout to 100%

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Guest Mode Adoption | >30% of new users | Analytics |
| Migration Success Rate | >95% | Analytics |
| Data Loss Rate | <0.1% | Error tracking |
| Performance | <100ms local ops | Performance monitoring |
| User Satisfaction | >4.5/5 | App store reviews |

## Risks & Mitigation

### Risk 1: Data Loss During Migration
- **Mitigation**: Create ZIP backup before migration
- **Rollback**: Restore from backup if migration fails

### Risk 2: Poor Migration Success Rate
- **Mitigation**: Extensive testing, error handling
- **Rollback**: Disable guest mode, force sign-in

### Risk 3: Performance Degradation
- **Mitigation**: Performance testing, optimization
- **Rollback**: Revert to Firestore-only

### Risk 4: User Confusion
- **Mitigation**: Clear UI/UX, help documentation
- **Rollback**: Simplify UI, add more guidance

## Compliance

### GDPR Compliance
- ✅ Data minimization (no PII in guest mode)
- ✅ Right to access (export feature)
- ✅ Right to erasure (uninstall app)
- ✅ Data portability (CSV/ZIP export)
- ✅ Consent (no consent needed for local storage)

### InvTrack Enterprise Rules Compliance
- ✅ Architecture: Clean layer boundaries maintained
- ✅ Security: OWASP MASVS compliant
- ✅ Privacy: PrivacyProtectionWrapper works in both modes
- ✅ Localization: All strings in ARB files
- ✅ Multi-Currency: Complies with Rule 21 (original data preserved)
- ✅ Data Lifecycle: Cleanup on migration/uninstall
- ✅ Testing: Comprehensive test coverage
- ✅ Documentation: Help & FAQ updated

## Next Steps

1. **Review this plan** with the team
2. **Approve architecture** and technical approach
3. **Create JIRA tickets** for each phase
4. **Start Phase 1** (Foundation) implementation
5. **Set up CI/CD** for guest mode testing
6. **Monitor progress** weekly

## Questions & Answers

### Q: What happens if user uninstalls app in guest mode?
**A**: All local data is deleted. We show periodic backup reminders during normal app usage to encourage export or sign-in.

### Q: Can guest users access multi-currency features?
**A**: Yes, but with cached exchange rates. We show "estimated" label and encourage sign-in for live rates.

### Q: What if migration fails?
**A**: Guest data is backed up before migration. User can retry or continue in guest mode.

### Q: Can users switch back to guest mode after signing in?
**A**: No, once migrated to cloud, data stays in cloud. User can export and create new guest session if needed.

### Q: How do we handle duplicate data during migration?
**A**: We detect duplicates and prompt user to choose: keep both, skip duplicates, or cancel migration.

## Conclusion

Guest Mode is a **low-risk, high-value** feature that:
- ✅ Lowers barrier to entry for new users
- ✅ Maintains full feature compatibility
- ✅ Provides seamless migration to cloud
- ✅ Complies with all InvTrack Enterprise Rules
- ✅ Enhances privacy and offline-first experience

**Estimated Timeline**: 5 weeks
**Estimated Effort**: 1 developer full-time
**Risk Level**: Low (with proper testing)
**User Impact**: High (positive)

---

**Ready to implement?** Start with Phase 1 (Foundation) and iterate based on feedback.

