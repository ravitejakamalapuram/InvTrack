# Enterprise Code Review Standards – InvTrack

These standards define comprehensive review types for enterprise mobile applications, aligned with industry frameworks (OWASP MASVS, WCAG, SOC2, GDPR).

---

## REVIEW TYPE 1: OWASP MASVS Security Review

Based on OWASP Mobile Application Security Verification Standard v2.0:

### MASVS-STORAGE (Data at Rest)
- [ ] Sensitive data not stored in plain text
- [ ] No credentials in code or config files
- [ ] Secure storage used for tokens (FlutterSecureStorage)
- [ ] Backup data excluded from cloud backup (Android `allowBackup=false`)
- [ ] Clipboard data cleared for sensitive fields
- [ ] No sensitive data in logs or crash reports

### MASVS-CRYPTO (Cryptography)
- [ ] Strong, modern algorithms used (AES-256, SHA-256+)
- [ ] No deprecated crypto (MD5, SHA1, DES)
- [ ] Keys not hardcoded
- [ ] Secure random number generation
- [ ] Proper key management lifecycle

### MASVS-AUTH (Authentication & Authorization)
- [ ] Biometric authentication properly implemented
- [ ] Session management secure (token expiry, refresh)
- [ ] Re-authentication for sensitive operations
- [ ] Authorization checks server-side, not client-only
- [ ] Password/PIN complexity enforced

### MASVS-NETWORK (Data in Transit)
- [ ] All connections use TLS 1.2+
- [ ] Certificate pinning considered for high-security
- [ ] No sensitive data in URLs/query params
- [ ] Proper error handling for network failures
- [ ] Timeout handling for offline scenarios

### MASVS-PLATFORM (Platform Interaction)
- [ ] Deep links validated and sanitized
- [ ] IPC data validated (intents, URL schemes)
- [ ] WebView security (JavaScript disabled if not needed)
- [ ] Permissions follow least-privilege principle
- [ ] No sensitive data exposed via platform APIs

### MASVS-CODE (Code Quality)
- [ ] Input validation on all user inputs
- [ ] No SQL/NoSQL injection vulnerabilities
- [ ] Memory management proper (dispose controllers)
- [ ] Third-party dependencies audited
- [ ] Debug code stripped in release builds

### MASVS-RESILIENCE (Tampering & Reverse Engineering)
- [ ] Root/jailbreak detection considered
- [ ] Code obfuscation enabled for release
- [ ] Tampering detection for high-security features
- [ ] Anti-debugging measures (if required)

### MASVS-PRIVACY
- [ ] Privacy policy accessible
- [ ] Data minimization practiced
- [ ] User consent obtained before data collection
- [ ] Data deletion supported (delete account)
- [ ] No unnecessary tracking or analytics

---

## REVIEW TYPE 2: Accessibility Review (WCAG 2.1/2.2)

### Perceivable
- [ ] All images have semantic labels
- [ ] Color not sole means of conveying information
- [ ] Sufficient color contrast (4.5:1 for text)
- [ ] Text scalable to 200% without loss
- [ ] Screen reader compatible (Semantics widgets)

### Operable
- [ ] All interactive elements keyboard/focus accessible
- [ ] Focus order logical and intuitive
- [ ] No time limits without extensions
- [ ] Touch targets minimum 44x44 dp
- [ ] Gestures have alternatives

### Understandable
- [ ] Error messages clear and actionable
- [ ] Form labels and instructions provided
- [ ] Consistent navigation patterns
- [ ] Language properly set for localization

### Robust
- [ ] Works with assistive technologies (TalkBack, VoiceOver)
- [ ] Valid semantic markup
- [ ] Status messages announced to screen readers

---

## REVIEW TYPE 3: Compliance Review

### GDPR Compliance
- [ ] Lawful basis for data processing documented
- [ ] Privacy notice accessible before data collection
- [ ] Right to access data implemented (export feature)
- [ ] Right to erasure implemented (delete account)
- [ ] Data portability supported (ZIP export)
- [ ] Data minimization practiced
- [ ] Consent obtained and recorded
- [ ] Data breach notification process exists

### SOC 2 Type II Alignment
- [ ] Access controls implemented (authentication)
- [ ] Encryption at rest and in transit
- [ ] Audit logging for sensitive operations
- [ ] Change management process followed
- [ ] Incident response procedures defined

### Financial Data Security (if applicable)
- [ ] No financial account numbers stored locally
- [ ] Investment values anonymized in analytics
- [ ] Secure handling of import/export data

---

## REVIEW TYPE 4: Architecture Review
Reference: `augment_flutter_enterprise_rules.md`

- [ ] UI → State → Domain → Data layering respected
- [ ] No API calls in widgets
- [ ] No business logic in UI layer
- [ ] No navigation logic in domain layer
- [ ] Repository pattern followed
- [ ] Provider scoping correct (autoDispose, family)

---

## REVIEW TYPE 5: Performance Review
Reference: `performance_rules.md`

- [ ] Widget rebuilds minimized (ref.select, const)
- [ ] ListView.builder for lists
- [ ] Controllers disposed properly
- [ ] Images optimized and cached
- [ ] Heavy operations in compute()
- [ ] No async/await in build methods

---

## REVIEW TYPE 6: Data Lifecycle Review
Reference: `firebase_data_rules.md`, Enterprise Rule 18

### New Data Storage
- [ ] Collection structure follows `users/{userId}/collection` pattern
- [ ] Security rules added to `firestore.rules`
- [ ] Indexes added if compound queries needed

### Delete Account Impact
- [ ] New data included in `deleteUserData()` flow
- [ ] Cascading deletes handled
- [ ] No orphaned data after deletion

### Export/Import Impact
- [ ] New data included in ZIP export (if applicable)
- [ ] Import service handles new data
- [ ] Version compatibility for old exports

---

## REVIEW TYPE 7: Localization Review

- [ ] All user-facing strings in ARB files
- [ ] No hardcoded dates/times/numbers/currency
- [ ] RTL layout support verified
- [ ] Pluralization handled correctly
- [ ] Context provided for translators

---

## REVIEW TYPE 8: Testing Review
Reference: `augment_flutter_pr_rules.md` Rule 8-9

- [ ] Unit tests for new business logic
- [ ] Widget tests for new UI components
- [ ] Integration tests for critical flows
- [ ] Bug fixes include regression tests
- [ ] No skipped or flaky tests
- [ ] Edge cases covered (empty, error, loading states)
- [ ] Mock usage follows guidelines (side-effects only)

---

## REVIEW PROCESS

### Pre-Review (Author)
1. Self-review against applicable review types
2. Run `flutter analyze` - zero errors/warnings
3. Run `flutter test` - all passing
4. Update PR description with checklist completion

### Review Assignment
| PR Type | Required Reviews |
|---------|------------------|
| Feature (new data) | Architecture + Security + Data Lifecycle |
| Feature (UI only) | Accessibility + Performance |
| Bug fix | Testing + Regression verification |
| Refactor | Architecture + Performance |
| Security fix | Security + OWASP MASVS |
| Dependency update | Security + Compatibility |

### Review Execution
1. **Automated Checks** (CI):
   - Static analysis (`flutter analyze`)
   - Tests (`flutter test`)
   - File size limits (Code Health Rule 3)
   - Architecture boundary checks

2. **Manual Review**:
   - Apply relevant review type checklists
   - Check for anti-patterns
   - Verify backward compatibility
   - Test on device if UI changes

### Post-Review
1. Author addresses all comments
2. Re-review of changes
3. Final approval with checklist sign-off

---

## REVIEWER RESPONSIBILITIES

### Security Reviewer
- Apply OWASP MASVS checklist
- Check for sensitive data exposure
- Verify authentication/authorization
- Review third-party dependencies

### Accessibility Reviewer
- Test with screen reader (TalkBack/VoiceOver)
- Verify touch targets and focus order
- Check color contrast
- Verify semantic labels

### Architecture Reviewer
- Verify layer boundaries
- Check for code duplication
- Review state management patterns
- Assess scalability

### Performance Reviewer
- Check widget rebuild scope
- Verify resource disposal
- Review async patterns
- Check image/asset optimization

---

## SIGN-OFF CRITERIA

### Mandatory for ALL PRs
- [ ] Zero analyzer errors/warnings
- [ ] All tests passing
- [ ] No hardcoded strings (localization)
- [ ] No sensitive data in logs

### Feature PRs (additionally)
- [ ] OWASP MASVS review completed
- [ ] Accessibility review completed
- [ ] Data lifecycle impact assessed
- [ ] Performance review completed

### Security PRs (additionally)
- [ ] Full OWASP MASVS checklist completed
- [ ] Penetration test considerations documented
- [ ] Threat model updated (if applicable)

### Compliance PRs (additionally)
- [ ] GDPR impact assessment completed
- [ ] Privacy policy update reviewed
- [ ] Data processing documentation updated

---

## ANTI-PATTERNS TO REJECT

### Security Anti-Patterns
- ❌ Hardcoded credentials or API keys
- ❌ Sensitive data in logs or analytics
- ❌ Disabled SSL/TLS verification
- ❌ Storing passwords in SharedPreferences
- ❌ SQL/NoSQL injection vulnerabilities

### Architecture Anti-Patterns
- ❌ API calls directly in widgets
- ❌ Business logic in UI layer
- ❌ God classes (>500 lines)
- ❌ Circular dependencies
- ❌ ref.read in build methods

### Performance Anti-Patterns
- ❌ Column with 100+ children (use ListView.builder)
- ❌ Missing const constructors
- ❌ Watching entire provider when subset needed
- ❌ Async/await in build methods
- ❌ Undisposed controllers/subscriptions

### Accessibility Anti-Patterns
- ❌ Images without semantic labels
- ❌ Touch targets <44dp
- ❌ Color-only information
- ❌ Missing focus management
- ❌ Non-descriptive button labels

---

## INTEGRATION WITH CI

The `augment-enterprise-review.yml` workflow automates:
- Static analysis (Code Health)
- Test verification
- File size enforcement
- Architecture boundary detection
- PR classification

Manual reviews remain required for:
- OWASP MASVS security assessment
- Accessibility testing with assistive tech
- Complex architecture decisions
- Compliance verification

