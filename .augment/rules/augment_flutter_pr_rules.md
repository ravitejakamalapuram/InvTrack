# Augment PR Rules – Enterprise Flutter Mobile Project

These rules apply to **every Pull Request**.  
Augment must **block, comment, or request changes** if any rule is violated.

---

## PR RULE 1: PR INTENT & SCOPE
Every PR MUST clearly state:
- What problem it solves
- Why the change is needed
- Whether it is:
  - Feature
  - Bug fix
  - Refactor
  - Tech debt
- Impacted app flows:
  - Pre-login
  - Post-login
  - Landing / onboarding

❌ Vague PR descriptions are not allowed.

---

## PR RULE 2: ARCHITECTURE CONFIRMATION
PR description MUST include:
- Confirmation that:
  - Architecture plan was created
  - Architecture review was done (pre-implementation)
- Summary of:
  - Planned vs actual architecture
  - Any deviations (with reasons)

❌ No architecture context → PR must be blocked.

---

## PR RULE 3: APP FLOW & PRE-LOGIN IMPACT
PR MUST explicitly answer:
- Does this change affect:
  - Landing pages?
  - Logged-out users?
  - First-time user experience?
- If YES:
  - Screens updated
  - UX validated
  - Localization verified

❌ Missing app-flow analysis → PR rejected.

---

## PR RULE 4: ZERO PATCH POLICY
- No temporary fixes
- No TODOs for core logic
- No commented-out production code
- No hacks justified by “time constraints”

If patching is detected → PR must be rejected.

---

## PR RULE 5: CODE QUALITY & STRUCTURE
Augment must verify:
- No duplicated logic
- Enums used instead of magic strings/booleans
- Proper layering respected:
  - UI → State → Domain → Data
- Existing components reused

❌ Architecture violations → PR blocked.

---

## PR RULE 6: LOCALIZATION & FORMATTING CHECK
PR must confirm:
- No hardcoded:
  - Dates
  - Numbers
  - Currency
- Localization used everywhere applicable
- Pre-login text localized if impacted

❌ Hardcoded formats → PR rejected.

---

## PR RULE 7: DESIGN SYSTEM COMPLIANCE
PR must confirm:
- Existing design system components reused
- No custom UI without approval
- Loading / error / empty states handled

❌ Visual regressions → PR blocked.

---

## PR RULE 8: TEST REQUIREMENTS (MANDATORY)
PR MUST include:
- Tests for all new features
- Tests for all new states
- Tests for all bug fixes (root cause covered)

❌ Bug fix without test → PR rejected.

---

## PR RULE 9: TEST VERIFICATION
PR must state:
- All tests run locally
- All tests passing
- No skipped or flaky tests introduced

❌ Failing or skipped tests → PR blocked.

---

## PR RULE 10: HOT RELOAD & RUNTIME CHECK
PR must confirm:
- Hot reload tested
- No runtime errors
- State preserved where expected

---

## PR RULE 11: VERSIONING & RELEASE IMPACT
If version is bumped:
- Semantic versioning followed
- CHANGELOG updated
- Store descriptions updated if user-visible change
- Release notes written

❌ Version bump without metadata → PR rejected.

---

## PR RULE 12: CODE RETRIEVAL VERIFICATION
PR must confirm:
- Existing code and assets were retrieved
- No assumptions made
- No hallucinated APIs or components

❌ Assumptions detected → PR rejected.

---

## PR RULE 13: SENIOR-LEVEL SELF REVIEW
PR description MUST include:
- Summary of senior-level self review:
  - Scalability
  - Readability
  - Maintainability
- Known risks or follow-ups (if any)

---

## PR RULE 14: DATA LIFECYCLE VERIFICATION
For PRs introducing new data storage (Firestore collections, local storage, etc.):

### Delete Account Impact
PR MUST confirm:
- [ ] New collections/data identified
- [ ] Delete account flow updated to purge new data
- [ ] Cascading deletes tested
- [ ] No orphaned data after account deletion

### Export/Import Impact
PR MUST confirm:
- [ ] Decision documented: Include in ZIP export? (Yes/No with reason)
- [ ] If Yes: Export service updated
- [ ] If Yes: Import service updated
- [ ] Version compatibility handled for old exports

### Re-Signup Data Isolation
PR MUST confirm:
- [ ] Data properly scoped to user ID
- [ ] Old data will NOT resurface on re-signup
- [ ] Query filters exclude orphaned/deleted user data

❌ New data storage without lifecycle verification → PR REJECTED

---

## PR RULE 15: MULTI-PERSPECTIVE REVIEW REQUIREMENT
For new features or significant changes, PR MUST include evidence of:

### Review Checklist
- [ ] Architect Review completed
  - Data model validated
  - Scalability assessed
  - Security reviewed
- [ ] Product Manager Review completed
  - User flow validated
  - Edge cases handled
  - UX patterns verified
- [ ] Senior Flutter Dev Review completed
  - Code quality verified
  - Performance optimized
  - Widget rebuilds scoped
- [ ] Enterprise Rules Compliance verified
  - All 18+ rules checked
  - No violations found

### Review Summary Required
PR description MUST include:
- Summary of each review perspective
- List of issues found and resolved
- Confirmation of 100% confidence in implementation

❌ Missing multi-perspective review → PR BLOCKED

---

## PR RULE 16: FINAL MERGE GATE
PR can be merged ONLY IF:
- All rules above are satisfied (1-15)
- No blocking comments from Augment
- Architecture integrity preserved
- Tests fully green
- Data lifecycle verified (if applicable)
- Multi-perspective review completed (for features)

Violation of any rule = **NO MERGE**.