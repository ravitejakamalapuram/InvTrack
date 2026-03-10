# Automated PR Review Guide - InvTrack

## 🎯 Overview

InvTrack uses **CodeRabbit** for automated AI-powered PR reviews. CodeRabbit automatically reviews every pull request and provides intelligent feedback based on InvTrack Enterprise Rules.

---

## ✅ What's Configured

### **CodeRabbit AI Reviewer**
- **Status:** ✅ Installed and configured
- **Cost:** FREE (75 PR reviews/month)
- **Configuration:** `.coderabbit.yaml`
- **Triggers:** Automatically on every PR (opened, synchronized)

### **What CodeRabbit Reviews:**

1. **Architecture Compliance**
   - Clean architecture boundaries (UI → State → Domain → Data)
   - No API calls in widgets
   - No navigation in domain layer
   - No ref.read in build methods

2. **Riverpod Best Practices**
   - Proper provider usage (ref.watch vs ref.read)
   - AsyncValue state handling (data, loading, error)
   - Provider disposal (.autoDispose)

3. **Localization**
   - All user-facing strings in ARB files
   - No hardcoded strings
   - Proper ARB file structure

4. **Privacy & Security**
   - Financial data wrapped in PrivacyProtectionWrapper
   - No hardcoded secrets
   - No print statements in production

5. **Multi-Currency Compliance**
   - Currency amounts use formatCompactCurrency() with locale
   - Original data preserved on currency changes
   - Proper currency field storage

6. **Accessibility**
   - Semantic labels on images
   - Touch targets ≥44dp
   - Screen reader compatibility

7. **Testing**
   - Bug fixes include regression tests
   - Proper test structure (it() not test())
   - Correct mocking patterns

8. **Code Quality**
   - File size limits (screens ≤500 lines, widgets ≤300 lines)
   - Cyclomatic complexity <15 per 100 lines
   - Proper const usage
   - Resource disposal

---

## 🚀 How It Works

### **Automatic Review Process:**

1. **You create a PR** → CodeRabbit is triggered
2. **CodeRabbit analyzes** → Reviews code against InvTrack rules
3. **CodeRabbit comments** → Provides line-by-line feedback
4. **You address feedback** → Make changes and push
5. **CodeRabbit re-reviews** → Verifies fixes automatically

### **What You'll See:**

- **PR Summary:** High-level overview of changes
- **Line Comments:** Specific suggestions on code
- **Rule Violations:** Flags InvTrack Enterprise Rule violations
- **Best Practices:** Suggests Flutter/Dart improvements
- **Security Issues:** Highlights potential vulnerabilities

---

## 💬 Interacting with CodeRabbit

### **Ask Questions:**
You can chat with CodeRabbit directly in PR comments:

```
@coderabbit Why is this flagged as a violation?
@coderabbit How should I fix this architecture issue?
@coderabbit Is this the correct way to handle AsyncValue?
```

### **Request Re-review:**
After making changes:

```
@coderabbit review
```

### **Ignore Specific Comments:**
If you disagree with a suggestion:

```
@coderabbit ignore
```

---

## 📋 Example Review Output

CodeRabbit will comment like this:

```markdown
## 🔍 Code Review

### ⚠️ Architecture Violation
**File:** lib/features/investments/presentation/widgets/investment_card.dart
**Line:** 45

Found `FirebaseFirestore` import in widget layer.

**Issue:** Widgets should not directly access Firestore (violates clean architecture).

**Suggestion:**
- Move Firestore logic to repository layer
- Access data through providers in presentation layer

**InvTrack Rule:** Section 1.1 - Layer Boundaries
```

---

## 🔧 Configuration

### **Current Configuration:** `.coderabbit.yaml`

The configuration enforces all InvTrack Enterprise Rules:
- Architecture boundaries
- Riverpod patterns
- Localization requirements
- Privacy protection
- Multi-currency compliance
- Accessibility standards
- Testing requirements
- Code quality standards

### **Customizing Reviews:**

To adjust CodeRabbit's behavior, edit `.coderabbit.yaml`:

```yaml
reviews:
  profile: "chill"  # Options: "chill", "assertive"
  auto_review:
    enabled: true
    drafts: false  # Don't review draft PRs
```

---

## 📊 Monitoring Usage

### **Free Tier Limits:**
- **75 PR reviews/month** (should be sufficient for personal projects)
- Resets monthly

### **Check Usage:**
- Go to: https://app.coderabbit.ai/
- View dashboard for usage stats

### **If You Exceed Limits:**
- **Option 1:** Upgrade to Pro ($12/month)
- **Option 2:** Add Qodo PR-Agent (free, unlimited) as backup
- **Option 3:** Wait for monthly reset

---

## 🆘 Troubleshooting

### **CodeRabbit Not Reviewing:**

1. **Check PR is not draft:**
   - CodeRabbit skips draft PRs by default
   - Mark PR as "Ready for review"

2. **Check GitHub App permissions:**
   - Go to: Settings → Integrations → Applications
   - Verify CodeRabbit has access to repository

3. **Manually trigger review:**
   - Comment: `@coderabbit review`

### **Too Many Comments:**

If CodeRabbit is too verbose:

1. Edit `.coderabbit.yaml`:
   ```yaml
   reviews:
     profile: "chill"  # Less aggressive
   ```

2. Or ask CodeRabbit to focus:
   ```
   @coderabbit focus on architecture violations only
   ```

---

## 🔄 Backup Option: Qodo PR-Agent

If you need unlimited reviews or want a backup, you can add Qodo PR-Agent (see setup below).

---

## 📚 Resources

- **CodeRabbit Docs:** https://docs.coderabbit.ai/
- **InvTrack Enterprise Rules:** `.augment/rules/invtrack_rules.md`
- **Flutter Best Practices:** https://dart.dev/guides/language/effective-dart
- **Riverpod Docs:** https://riverpod.dev/

---

## ✅ Next Steps

1. **Create a test PR** to see CodeRabbit in action
2. **Review CodeRabbit's feedback** and address issues
3. **Iterate** - CodeRabbit learns from your codebase over time
4. **Enjoy automated reviews!** 🎉

---

*Last Updated: 2026-03-10*

