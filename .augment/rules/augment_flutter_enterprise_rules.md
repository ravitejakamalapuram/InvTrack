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