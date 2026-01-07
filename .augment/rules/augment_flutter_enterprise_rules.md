---
type: "always_apply"
---

# Augment Rules – Enterprise Flutter Mobile Project

These rules are **MANDATORY** for all Flutter mobile development using Augment.

---

## RULE 1: THINK BEFORE YOU CODE
Before implementing ANY feature:
- Review product roadmap and future plans
- Evaluate full app flow:
  - Landing pages
  - Pre-login / logged-out experience
  - Onboarding flows
- Decide if feature info must appear before login
- Create an architecture plan
- Get architecture approval before writing code

---

## RULE 2: ZERO PATCH POLICY
- No temporary fixes
- No shortcuts
- No ad-hoc logic
- Follow existing architectural patterns only
- Any deviation must be justified and documented

---

## RULE 3: STRICT ARCHITECTURE BOUNDARIES
- UI (Widgets) → State → Domain → Data
- No API calls in widgets
- No business logic in UI
- No navigation logic in domain

---

## RULE 4: STRONG TYPING & ENUMS
- Use enums for:
  - UI states
  - Feature states
  - Events and actions
- No magic strings
- No boolean explosion patterns

---

## RULE 5: REUSABILITY OVER DUPLICATION
- Zero code duplication
- Reuse:
  - Design system components
  - Domain logic
  - Theme extensions
- Duplication = architecture bug

---

## RULE 6: LOCALIZATION IS NOT OPTIONAL
- Always use app localization for:
  - Dates
  - Times
  - Numbers
  - Currency
- Never hardcode formats or symbols
- Respect user locale and platform standards

---

## RULE 7: DESIGN SYSTEM COMPLIANCE
- Follow app design standards
- Reuse components before creating new ones
- Handle:
  - Loading
  - Empty
  - Error states
- No custom UI without approval

---

## RULE 8: VERIFY, DON’T ASSUME
- Always retrieve existing code and assets
- Never guess APIs or structures
- No hallucinated code
- If code cannot be retrieved, STOP

---

## RULE 9: POST-CODING VALIDATION
After implementation:
- Fix all:
  - Analyzer errors
  - Lint warnings
  - Type issues
- Remove:
  - Dead code
  - Debug logs
  - Unused assets

---

## RULE 10: TESTING IS MANDATORY
- Write exhaustive tests for:
  - New features
  - New states
  - Edge cases
- Every bug fix MUST include tests
- A bug without a test is an incomplete fix

---

## RULE 11: TEST GATE
- Run full test suite
- No skipped tests
- No flaky tests
- All tests must pass locally and in CI

---

## RULE 12: ARCHITECTURE RE-REVIEW
- Re-review architecture post-implementation
- Validate no drift from approved design
- Document deviations clearly

---

## RULE 13: SENIOR-LEVEL SELF REVIEW
Review code as a Staff Flutter Engineer:
- Is state flow obvious?
- Are rebuilds scoped?
- Is logic readable?
- Will this scale?
Apply fixes and re-validate

---

## RULE 14: HOT RELOAD VERIFICATION
- Hot reload the app
- Validate UI consistency
- Validate state preservation
- No runtime errors allowed

---

## RULE 15: RELEASE & VERSIONING
When raising PR and bumping version:
- Follow semantic versioning
- Update:
  - CHANGELOG
  - Store descriptions
  - Short descriptions
  - Release notes
- Store text MUST match actual behavior

---

## RULE 16: FINAL HARD STOP
Work is DONE only if:
- Architecture approved
- App flow reviewed
- No patching
- Localization applied
- Design system followed
- Tests exhaustive & passing
- Version & store metadata updated
- Code verified from real sources

## RULE 17: SELF IMPROVEMENT
for every task or bug or issue i ask you to do, improve your rules set so that you can learn form your mistekes proactively

---

## RULE 18: NEW FEATURE DATA LIFECYCLE PLANNING
For ANY new feature that introduces new data, collections, or storage:

### 18.1 Delete Account Impact Analysis
Before implementation, answer:
- Does this feature create new Firestore collections or documents?
- Does this feature store data in local storage (Hive, SharedPreferences, etc.)?
- If YES to any:
  - Update delete account flow to purge this data
  - Ensure cascading deletes are handled
  - Test that orphaned data is not left behind

### 18.2 Export/Import Impact Analysis
Before implementation, answer:
- Should this new data be included in ZIP exports?
- Should this new data be importable from ZIP backups?
- If YES:
  - Update export service to include new collections/data
  - Update import service to handle new collections/data
  - Handle version compatibility (old exports without this data)
  - Write migration logic if schema changes

### 18.3 Re-Signup Data Isolation
Before implementation, answer:
- If user deletes account and re-signs up, will old data resurface?
- Ensure user-bound data is:
  - Properly scoped to user ID
  - Deleted on account deletion (not just hidden)
  - OR explicitly marked as orphaned and excluded from queries

❌ New feature with data storage but no lifecycle plan → REJECTED

---

## RULE 19: COMPREHENSIVE MULTI-PERSPECTIVE REVIEW
When asked to review a feature, perform FOUR separate reviews with 100% confidence validation:

### 19.1 Architect Review
Evaluate as a Solution Architect:
- Is the data model correct and normalized?
- Are there any scalability bottlenecks?
- Is the feature properly decoupled?
- Are there circular dependencies?
- Is the state management appropriate?
- Are there any security concerns?
- Is offline-first considered?
- Are edge cases handled?

### 19.2 Product Manager Review
Evaluate as a Product Manager:
- Does the feature solve the user problem?
- Is the user flow intuitive?
- Are edge cases handled gracefully (empty states, errors)?
- Is the feature discoverable?
- Are analytics/tracking implemented?
- Is the feature accessible?
- Does it align with product roadmap?
- Are there any UX anti-patterns?

### 19.3 Senior Flutter Developer Review
Evaluate as a Staff Flutter Engineer:
- Is the code idiomatic Flutter/Dart?
- Are widget rebuilds optimized?
- Is state properly scoped and managed?
- Are there memory leaks?
- Is error handling comprehensive?
- Are there any performance issues?
- Is the code testable?
- Are best practices followed (const, keys, disposal)?
- Is the UI responsive across screen sizes?
- Are animations smooth and purposeful?

### 19.4 Enterprise Rules Compliance Review
Validate against ALL enterprise rules (1-18):
- Architecture boundaries respected?
- Zero patch policy followed?
- Design system compliance?
- Localization complete?
- Tests comprehensive?
- Data lifecycle planned?

### 19.5 Review Collation
After all four reviews:
- Collate all findings
- Prioritize by severity (Critical → High → Medium → Low)
- Present actionable fix recommendations
- Require re-review after fixes

❌ Feature without comprehensive review → NOT PRODUCTION READY