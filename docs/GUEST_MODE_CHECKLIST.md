# Guest Mode Implementation Checklist

## Phase 1: Foundation (Week 1)

### Dependencies
- [ ] Add `hive: ^2.2.3` to `pubspec.yaml`
- [ ] Add `hive_flutter: ^1.1.0` to `pubspec.yaml`
- [ ] Add `path_provider: ^2.1.1` to `pubspec.yaml` (if not already present)
- [ ] Run `flutter pub get`

### Hive Setup
- [ ] Initialize Hive in `main.dart` before `runApp()`
- [ ] Create `lib/core/di/hive_module.dart` for Hive providers
- [ ] Register Hive adapters for all entities

### Hive Type Adapters
- [ ] Create `lib/features/investment/data/models/investment_hive_model.dart`
- [ ] Create `lib/features/investment/data/models/cashflow_hive_model.dart`
- [ ] Create `lib/features/goals/data/models/goal_hive_model.dart`
- [ ] Create `lib/features/investment/data/models/document_hive_model.dart`
- [ ] Create `lib/features/settings/data/models/settings_hive_model.dart`
- [ ] Create `lib/features/fire_number/data/models/fire_settings_hive_model.dart`
- [ ] Create `lib/features/user_profile/data/models/user_profile_hive_model.dart`
- [ ] Create `lib/core/services/exchange_rate_hive_model.dart`
- [ ] Run `flutter packages pub run build_runner build` to generate adapters

### Hive Repositories
- [ ] Create `lib/features/investment/data/repositories/hive_investment_repository.dart`
- [ ] Implement all methods from `InvestmentRepository` interface
- [ ] Create `lib/features/goals/data/repositories/hive_goal_repository.dart`
- [ ] Implement all methods from `GoalRepository` interface
- [ ] Create `lib/features/investment/data/repositories/hive_document_repository.dart`
- [ ] Implement all methods from `DocumentRepository` interface
- [ ] Create `lib/features/settings/data/repositories/hive_settings_repository.dart`
- [ ] Create `lib/features/fire_number/data/repositories/hive_fire_settings_repository.dart`
- [ ] Create `lib/features/user_profile/data/repositories/hive_user_profile_repository.dart`

### Local Document Storage
- [ ] Create `lib/features/investment/data/services/local_document_storage_service.dart`
- [ ] Implement `saveDocument()` method
- [ ] Implement `readDocument()` method
- [ ] Implement `deleteDocument()` method
- [ ] Implement `listDocuments()` method

### Repository Providers
- [ ] Update `lib/core/di/repository_module.dart`
- [ ] Create `hiveInvestmentRepositoryProvider`
- [ ] Create `hiveGoalRepositoryProvider`
- [ ] Create `hiveDocumentRepositoryProvider`
- [ ] Update `investmentRepositoryProvider` to select based on auth state
- [ ] Update `goalRepositoryProvider` to select based on auth state
- [ ] Update `documentRepositoryProvider` to select based on auth state

### Testing
- [ ] Unit tests for `InvestmentHiveModel` conversion
- [ ] Unit tests for `HiveInvestmentRepository` CRUD operations
- [ ] Unit tests for `HiveGoalRepository` CRUD operations
- [ ] Unit tests for `LocalDocumentStorageService`

## Phase 2: Authentication (Week 2)

### User Entity Changes
- [ ] Add `isGuest` field to `UserEntity` in `lib/features/auth/domain/entities/user_entity.dart`
- [ ] Create `UserEntity.guest()` factory method
- [ ] Update `UserEntity` equality and hashCode
- [ ] Update `UserEntity` toString method

### Guest Auth Repository
- [ ] Create `lib/features/auth/data/repositories/guest_auth_repository.dart`
- [ ] Implement `AuthRepository` interface
- [ ] Implement `startGuestSession()` method
- [ ] Implement `endGuestSession()` method
- [ ] Store guest user ID in SharedPreferences

### Auth Provider Updates
- [ ] Create `guestModeEnabledProvider` in `lib/features/auth/presentation/providers/auth_provider.dart`
- [ ] Create `guestAuthRepositoryProvider`
- [ ] Update `authStateProvider` to support guest mode
- [ ] Create `isGuestModeProvider` for UI checks

### Router Changes
- [ ] Update `lib/core/router/app_router.dart`
- [ ] Modify redirect logic to allow guest access
- [ ] Remove mandatory sign-in requirement
- [ ] Keep onboarding flow intact

### Sign-In Screen
- [ ] Update `lib/features/auth/presentation/screens/sign_in_screen.dart`
- [ ] Add "Continue as Guest" button
- [ ] Add guest mode info dialog
- [ ] Add analytics tracking for guest mode start

### App Bar Indicator
- [ ] Create `lib/core/widgets/auth_mode_indicator.dart`
- [ ] Show "🔒 Guest Mode" when in guest mode
- [ ] Show "☁️ Synced" when signed in
- [ ] Add tap handler to show info/sign-in

### Testing
- [ ] Unit tests for `UserEntity.guest()`
- [ ] Unit tests for `GuestAuthRepository`
- [ ] Integration tests for guest mode auth flow
- [ ] Widget tests for sign-in screen with guest option

## Phase 3: Migration (Week 3)

### Migration Service
- [ ] Create `lib/features/auth/data/services/guest_data_migration_service.dart`
- [ ] Implement `migrateToCloud()` method
- [ ] Implement `_createBackup()` method
- [ ] Implement `_mergeData()` method
- [ ] Implement `_replaceData()` method
- [ ] Implement `_verifyMigration()` method
- [ ] Implement `_cleanupGuestData()` method

### Migration Models
- [ ] Create `MigrationStrategy` enum (merge/replace)
- [ ] Create `MigrationResult` class
- [ ] Create `MigrationProgress` class for UI updates

### Migration Provider
- [ ] Create `lib/features/auth/presentation/providers/migration_provider.dart`
- [ ] Create `MigrationNotifier` for state management
- [ ] Implement progress tracking
- [ ] Implement error handling

### Migration UI
- [ ] Create `lib/features/auth/presentation/screens/migration_prompt_screen.dart`
- [ ] Create `lib/features/auth/presentation/screens/migration_progress_screen.dart`
- [ ] Create `lib/features/auth/presentation/screens/migration_result_screen.dart`
- [ ] Add migration flow to router

### Migration Widgets
- [ ] Create `lib/features/auth/presentation/widgets/migration_strategy_card.dart`
- [ ] Create `lib/features/auth/presentation/widgets/migration_progress_indicator.dart`
- [ ] Create `lib/features/auth/presentation/widgets/migration_error_card.dart`

### Testing
- [ ] Unit tests for `GuestDataMigrationService`
- [ ] Integration tests for migration flow
- [ ] E2E tests for complete migration journey
- [ ] Test migration failure scenarios
- [ ] Test rollback mechanism

## Phase 4: UI/UX (Week 4)

### Settings Screen
- [ ] Update `lib/features/settings/presentation/screens/settings_screen.dart`
- [ ] Add guest mode account section
- [ ] Add "Sign In" button for guest users
- [ ] Show user info for signed-in users

### Upgrade Prompts
- [ ] Create `lib/features/auth/presentation/widgets/upgrade_prompt_dialog.dart`
- [ ] Implement periodic prompt (after 7 days)
- [ ] Implement export prompt (before uninstall)
- [ ] Add prompt scheduling logic

### Guest Mode Indicators
- [ ] Add guest mode badge to portfolio screen
- [ ] Add guest mode warning to documents screen
- [ ] Add "estimated" label to exchange rates in guest mode
- [ ] Update all relevant screens

### Localization
- [ ] Add guest mode strings to `lib/l10n/app_en.arb`
- [ ] Add migration strings to ARB file
- [ ] Add upgrade prompt strings to ARB file
- [ ] Run `flutter gen-l10n`

### Animations
- [ ] Add fade-in animation for guest mode indicator
- [ ] Add progress animation for migration
- [ ] Add success/error animations for migration result
- [ ] Add haptic feedback for key actions

### Help & FAQ
- [ ] Update `lib/features/settings/presentation/screens/help_faq_screen.dart`
- [ ] Add "What is Guest Mode?" section
- [ ] Add "How to migrate data?" section
- [ ] Add "What happens to my data?" section

### Testing
- [ ] Widget tests for all new UI components
- [ ] Screenshot tests for guest mode screens
- [ ] Accessibility tests (screen reader, contrast)
- [ ] Localization tests (all strings present)

## Phase 5: Testing & Polish (Week 5)

### Unit Tests
- [ ] Test coverage >80% for all new code
- [ ] Test all Hive repository methods
- [ ] Test all migration service methods
- [ ] Test all auth provider methods

### Integration Tests
- [ ] Test guest mode full flow
- [ ] Test sign-in from guest mode
- [ ] Test data migration end-to-end
- [ ] Test feature compatibility in guest mode

### E2E Tests
- [ ] Test onboarding → guest mode → create data → sign in → migrate
- [ ] Test migration with large dataset (1000+ items)
- [ ] Test migration failure scenarios
- [ ] Test rollback mechanism

### Performance Tests
- [ ] Benchmark Hive read/write operations
- [ ] Benchmark migration performance
- [ ] Test app startup time with Hive
- [ ] Test memory usage with Hive

### Edge Case Tests
- [ ] Test app killed during migration
- [ ] Test network lost during migration
- [ ] Test insufficient storage during migration
- [ ] Test duplicate data handling
- [ ] Test empty guest data migration

### Beta Testing
- [ ] Recruit 100 beta testers
- [ ] Deploy beta build with guest mode
- [ ] Monitor analytics (adoption, migration success)
- [ ] Gather feedback via in-app survey
- [ ] Fix critical bugs

### Polish
- [ ] Fix all analyzer warnings
- [ ] Fix all test failures
- [ ] Optimize performance bottlenecks
- [ ] Improve error messages
- [ ] Add loading states everywhere

### Documentation
- [ ] Update README.md with guest mode info
- [ ] Update ARCHITECTURE_OVERVIEW.md
- [ ] Update LOCALIZATION.md
- [ ] Update GOALS_FEATURE_PLAN.md (if affected)
- [ ] Create GUEST_MODE_TROUBLESHOOTING.md

## Final Checklist

### Code Quality
- [ ] Zero `flutter analyze` errors/warnings
- [ ] All tests passing (`flutter test`)
- [ ] Code formatted (`dart format .`)
- [ ] No debug print statements
- [ ] No commented-out code
- [ ] No TODOs without owner/date/issue

### Compliance
- [ ] Localization: All strings in ARB files
- [ ] Privacy: Financial data wrapped in PrivacyProtectionWrapper
- [ ] Security: No sensitive data in logs/analytics
- [ ] Accessibility: Semantic labels, touch targets ≥44dp
- [ ] Architecture: Clean layer boundaries
- [ ] Multi-Currency: Complies with Rule 21
- [ ] Data Lifecycle: Cleanup on migration/uninstall

### Documentation
- [ ] PR description explains what/why
- [ ] Breaking changes documented
- [ ] New dependencies justified
- [ ] Data lifecycle handled
- [ ] Help & FAQ screen updated

### Deployment
- [ ] Create release branch
- [ ] Update version number
- [ ] Update CHANGELOG.md
- [ ] Create release notes
- [ ] Deploy to beta track
- [ ] Monitor crash reports
- [ ] Monitor analytics
- [ ] Gradual rollout (10% → 50% → 100%)

## Success Criteria

- [ ] Guest mode adoption >30% of new users
- [ ] Migration success rate >95%
- [ ] Data loss rate <0.1%
- [ ] Performance: Local operations <100ms
- [ ] User satisfaction >4.5/5
- [ ] Zero critical bugs in production
- [ ] All InvTrack Enterprise Rules complied

---

**Estimated Timeline**: 5 weeks
**Estimated Effort**: 1 developer full-time
**Risk Level**: Low (with proper testing)
**User Impact**: High (positive)

