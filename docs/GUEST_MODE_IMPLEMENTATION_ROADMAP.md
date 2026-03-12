# Guest Mode Implementation Roadmap

## Overview

This document provides a step-by-step roadmap for implementing Guest Mode in InvTrack, based on the comprehensive planning and review process completed in PR #261.

**Status**: ✅ Planning Complete - Ready for Implementation  
**Timeline**: 5 weeks, 1 developer full-time  
**Risk Level**: Low (with proper testing)

---

## Pre-Implementation Checklist

Before starting Phase 1, ensure:

- [ ] PR #261 merged to main
- [ ] All team members reviewed documentation
- [ ] Development environment set up
- [ ] Test devices available (Android + iOS)
- [ ] Firebase project configured for testing
- [ ] JIRA tickets created for each phase

---

## Phase 1: Foundation (Week 1)

### Day 1-2: Dependencies & Setup

**Tasks**:
1. Add dependencies to `pubspec.yaml`:
   ```yaml
   dependencies:
     hive: ^2.2.3
     hive_flutter: ^1.1.0
     path_provider: ^2.1.5
     flutter_secure_storage: ^9.0.0
   
   dev_dependencies:
     hive_generator: ^2.0.1
     build_runner: ^2.4.6
   ```

2. Run `flutter pub get`

3. Initialize Hive in `main.dart`:
   ```dart
   Future<void> main() async {
     WidgetsFlutterBinding.ensureInitialized();
     
     // Initialize Hive
     await Hive.initFlutter();
     
     // Get encryption key
     final encryptionKey = await getHiveEncryptionKey();
     final cipher = HiveAesCipher(encryptionKey);
     
     // Open all boxes with encryption
     await Hive.openBox<InvestmentHiveModel>(
       'guest_investments',
       encryptionCipher: cipher,
     );
     // ... open other boxes
     
     runApp(ProviderScope(child: MyApp()));
   }
   ```

**Deliverables**:
- [ ] Dependencies installed
- [ ] Hive initialized in main.dart
- [ ] Encryption key management implemented
- [ ] All boxes opened successfully

**Testing**:
- Verify app starts without errors
- Check Hive boxes are created in app directory
- Verify encryption key stored in secure storage

---

### Day 3-4: Hive Models & Adapters

**Tasks**:
1. Create Hive models for all entities:
   - `InvestmentHiveModel`
   - `CashFlowHiveModel`
   - `GoalHiveModel`
   - `DocumentHiveModel`
   - `SettingsHiveModel`
   - `FireSettingsHiveModel`
   - `UserProfileHiveModel`
   - `ExchangeRateHiveModel`

2. Add `@HiveType` and `@HiveField` annotations

3. Run `dart run build_runner build` to generate adapters

4. Register adapters in `main.dart`:
   ```dart
   Hive.registerAdapter(InvestmentHiveModelAdapter());
   Hive.registerAdapter(CashFlowHiveModelAdapter());
   // ... register all adapters
   ```

**Deliverables**:
- [ ] All Hive models created
- [ ] Type adapters generated
- [ ] Adapters registered
- [ ] Build successful

**Testing**:
- Verify adapters compile without errors
- Test basic CRUD operations on each box

---

### Day 5: Hive Repositories

**Tasks**:
1. Create `HiveInvestmentRepository` implementing `InvestmentRepository`
2. Implement all methods using Hive boxes
3. Use `Stream.value().followedBy(box.watch())` pattern for streams
4. Add proper error handling

**Key Implementation**:
```dart
@override
Stream<List<InvestmentEntity>> watchAllInvestments() {
  return Stream.value(_getCurrentInvestments())
      .followedBy(
        _investmentsBox.watch().map((_) => _getCurrentInvestments()),
      );
}
```

**Deliverables**:
- [ ] HiveInvestmentRepository complete
- [ ] HiveGoalRepository complete
- [ ] All repository methods implemented
- [ ] Unit tests written

**Testing**:
- Unit test each repository method
- Verify stream emissions (initial + updates)
- Test error handling

### Day 4-5: Migration UI

**Tasks**:
1. Create migration prompt dialog
2. Add strategy selection UI
3. Implement progress indicator
4. Add error handling UI
5. Show success/failure feedback

**Deliverables**:
- [ ] Migration UI complete
- [ ] Progress tracking working
- [ ] Error messages user-friendly

**Testing**:
- Test migration flow end-to-end
- Test error scenarios
- Verify user feedback clear

---

## Phase 4: UI/UX (Week 4)

### Day 1-2: Guest Mode Indicators

**Tasks**:
1. Add guest mode indicator to app bar
2. Implement "Tap to sign in" functionality
3. Add signed-in indicator
4. Verify WCAG AAA contrast (7:1 or 4.5:1 for large text)

**Deliverables**:
- [ ] Guest indicator visible
- [ ] Contrast verified
- [ ] Tap to sign in working

**Testing**:
- Test on light and dark themes
- Verify accessibility with TalkBack/VoiceOver
- Check contrast ratios

---

### Day 3-4: Localization

**Tasks**:
1. Add all guest mode strings to ARB files
2. Include proper metadata for translators
3. Test with different locales
4. Verify no hardcoded strings

**Key Strings**:
```json
{
  "guestModeIndicator": "Guest mode",
  "@guestModeIndicator": {
    "description": "Indicator shown when user is in guest mode"
  },
  "tapToSignIn": "Tap to sign in",
  "migrateDataPrompt": "Migrate your local data to cloud?",
  "migrateDataDescription": "Your data will be backed up and synced across devices.",
  ...
}
```

**Deliverables**:
- [ ] All strings in ARB files
- [ ] Metadata complete
- [ ] No hardcoded strings

**Testing**:
- Test with different locales
- Verify all strings display correctly
- Run `flutter gen-l10n`

---

### Day 5: Help & FAQ Updates

**Tasks**:
1. Update `help_faq_screen.dart` with guest mode section
2. Add FAQ entries:
   - What is guest mode?
   - How to migrate data?
   - What happens to my data?
   - Can I switch back to guest mode?
3. Add troubleshooting tips

**Deliverables**:
- [ ] Help screen updated
- [ ] FAQ entries added
- [ ] Troubleshooting guide complete

**Testing**:
- Review help content for clarity
- Test all links and navigation

---

## Phase 5: Testing & Polish (Week 5)

### Day 1-2: Unit & Widget Tests

**Tasks**:
1. Write unit tests for all repositories
2. Write unit tests for migration service
3. Write widget tests for UI components
4. Achieve ≥80% code coverage

**Test Categories**:
- Repository CRUD operations
- Stream emissions (initial + updates)
- Migration strategies (merge, replace)
- Error handling
- UI components

**Deliverables**:
- [ ] All unit tests passing
- [ ] All widget tests passing
- [ ] Coverage ≥80%

**Testing**:
- Run `flutter test`
- Check coverage report
- Fix any failing tests

---

### Day 3: Integration Tests

**Tasks**:
1. Write integration tests for guest mode flow
2. Test migration end-to-end
3. Test data persistence
4. Test offline behavior

**Test Scenarios**:
- Guest creates data → signs in → migrates → verifies cloud data
- Guest creates data → uninstalls → reinstalls → data gone
- Guest creates data → exports → imports → data restored

**Deliverables**:
- [ ] Integration tests passing
- [ ] All scenarios covered

**Testing**:
- Run `flutter test integration_test/`
- Test on real devices

---

### Day 4: Performance Benchmarks

**Tasks**:
1. Create performance benchmarks in `integration_test/performance/`
2. Measure Hive vs Firestore operations
3. Validate target metrics (<10ms for Hive reads)
4. Document actual performance

**Deliverables**:
- [ ] Benchmarks created
- [ ] Performance validated
- [ ] Documentation updated

**Testing**:
- Run benchmarks on multiple devices
- Compare with target metrics
- Update IMPLICATIONS.md with actual numbers

---

### Day 5: Beta Testing & Bug Fixes

**Tasks**:
1. Deploy to internal beta testers
2. Collect feedback
3. Fix critical bugs
4. Polish UI/UX based on feedback

**Deliverables**:
- [ ] Beta deployed
- [ ] Feedback collected
- [ ] Critical bugs fixed
- [ ] Ready for production

**Testing**:
- Test on multiple devices
- Test with real user data
- Verify all edge cases

---

## Post-Implementation

### Documentation Updates

- [ ] Update README.md with guest mode info
- [ ] Update ARCHITECTURE_OVERVIEW.md
- [ ] Create user guide for guest mode
- [ ] Update API documentation

### Deployment

- [ ] Merge to main branch
- [ ] Create release notes
- [ ] Deploy to production
- [ ] Monitor analytics and crash reports

### Monitoring

- [ ] Track guest mode adoption rate
- [ ] Monitor migration success rate
- [ ] Track performance metrics
- [ ] Collect user feedback

---

## Success Metrics

**Adoption**:
- Target: 30% of new users start in guest mode
- Measure: Analytics event `guest_session_started`

**Migration**:
- Target: 70% of guest users migrate to cloud
- Measure: Analytics event `migration_completed`

**Performance**:
- Target: <10ms for Hive reads, <20ms for queries
- Measure: Performance benchmarks

**Quality**:
- Target: <1% crash rate in guest mode
- Measure: Crashlytics reports

---

## Risk Mitigation

### High-Risk Areas

1. **Data Loss During Migration**
   - Mitigation: Always create ZIP backup before migration
   - Rollback: Restore from backup if migration fails

2. **Performance Degradation**
   - Mitigation: Benchmark early, optimize as needed
   - Rollback: Feature flag to disable guest mode

3. **Security Vulnerabilities**
   - Mitigation: Use Hive encryption, sanitize file names
   - Rollback: Security audit before production

### Rollback Plan

If critical issues found:
1. Disable guest mode via feature flag
2. Force all guest users to sign in
3. Provide migration assistance
4. Fix issues in hotfix branch
5. Re-enable after validation

---

## Resources

**Documentation**:
- [GUEST_MODE_SUMMARY.md](./GUEST_MODE_SUMMARY.md) - Executive summary
- [GUEST_MODE_TECHNICAL_SPEC.md](./GUEST_MODE_TECHNICAL_SPEC.md) - Technical details
- [GUEST_MODE_IMPLEMENTATION_PLAN.md](./GUEST_MODE_IMPLEMENTATION_PLAN.md) - Architecture
- [GUEST_MODE_CHECKLIST.md](./GUEST_MODE_CHECKLIST.md) - Detailed checklist
- [GUEST_MODE_REVIEW_FIXES.md](./GUEST_MODE_REVIEW_FIXES.md) - All 49 fixes

**External Resources**:
- [Hive Documentation](https://docs.hivedb.dev/)
- [Riverpod Documentation](https://riverpod.dev/)
- [OWASP MASVS](https://mas.owasp.org/MASVS/)
- [WCAG AAA Guidelines](https://www.w3.org/WAI/WCAG2AAA-Conformance)

---

**Last Updated**: March 12, 2026
**Status**: Ready for Phase 1 Implementation
## Phase 2: Authentication (Week 2)

### Day 1-2: Guest User Entity & Repository

**Tasks**:
1. Add `isGuest` field to `UserEntity`
2. Create `UserEntity.guest()` factory
3. Implement `GuestAuthRepository`
4. Add guest session management (SharedPreferences)
5. Implement `dispose()` to prevent memory leaks

**Deliverables**:
- [ ] UserEntity updated
- [ ] GuestAuthRepository implemented
- [ ] Session persistence working
- [ ] Memory leaks prevented

**Testing**:
- Test guest user creation
- Test session persistence across app restarts
- Verify no memory leaks (dispose called)

---

### Day 3-4: Repository Provider Selection

**Tasks**:
1. Update repository providers to use `.when()` for AsyncValue
2. Implement conditional selection (guest vs signed-in)
3. Add proper error handling for all states
4. Remove auto-dispose box closure

**Key Implementation**:
```dart
final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) => (user == null || user.isGuest)
        ? ref.watch(hiveInvestmentRepositoryProvider)
        : ref.watch(firestoreInvestmentRepositoryProvider),
    loading: () => ref.watch(hiveInvestmentRepositoryProvider),
    error: (_, __) => ref.watch(hiveInvestmentRepositoryProvider),
  );
});
```

**Deliverables**:
- [ ] All repository providers updated
- [ ] AsyncValue handling correct
- [ ] No crashes on loading/error states

**Testing**:
- Test auth state transitions
- Verify correct repository selected
- Test loading and error states

---

### Day 5: Router Changes

**Tasks**:
1. Update router to allow guest mode
2. Add "Continue as Guest" option to sign-in screen
3. Implement guest session start/end
4. Update navigation guards

**Deliverables**:
- [ ] Router updated
- [ ] Sign-in screen updated
- [ ] Guest flow working

**Testing**:
- Test guest mode entry
- Test navigation to all screens
- Verify auth guards work correctly

---

## Phase 3: Data Migration (Week 3)

### Day 1-3: Migration Service

**Tasks**:
1. Implement `GuestDataMigrationService`
2. Add backup creation (ZIP export)
3. Implement merge strategy
4. Implement replace strategy (with limitation notes)
5. Add verification logic
6. Implement cleanup

**Deliverables**:
- [ ] Migration service complete
- [ ] Both strategies implemented
- [ ] Verification working
- [ ] Cleanup safe

**Testing**:
- Test merge strategy with sample data
- Test replace strategy
- Verify backup creation
- Test cleanup (no data loss)

---


