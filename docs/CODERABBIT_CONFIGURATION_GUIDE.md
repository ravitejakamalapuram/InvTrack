# CodeRabbit Configuration Guide - InvTrack

## 🎯 Overview

This document explains the comprehensive CodeRabbit configuration for InvTrack, which utilizes **all available CodeRabbit capabilities** for thorough, context-aware code reviews.

---

## 📋 Configuration File: `.coderabbit.yaml`

### **Location:** Project root
### **Schema:** https://coderabbit.ai/integrations/schema.v2.json
### **Profile:** Assertive (more thorough reviews)

---

## 🎨 Key Features Configured

### **1. Path-Specific Review Instructions**

CodeRabbit applies different review criteria based on file location:

#### **Presentation Layer - Widgets** (`lib/features/**/presentation/widgets/**/*.dart`)
- ❌ NO FirebaseFirestore, http, or dio imports
- ❌ NO business logic
- ❌ NO navigation code
- ✅ MUST use PrivacyProtectionWrapper for financial data
- ✅ MUST use AppLocalizations for all strings
- ✅ MUST use const constructors where possible
- ✅ Images MUST have semantic labels
- ✅ Touch targets MUST be ≥44dp

#### **Presentation Layer - Screens** (`lib/features/**/presentation/screens/**/*.dart`)
- ❌ NO direct API calls
- ❌ NO business logic
- ⚠️ File size SHOULD be ≤500 lines
- ✅ Use ref.watch in build methods
- ✅ Use ref.read in callbacks
- ✅ Handle ALL AsyncValue states (data, loading, error)
- ✅ Error messages MUST be user-friendly
- ✅ ALL strings in ARB files

#### **Presentation Layer - Providers** (`lib/features/**/presentation/providers/**/*.dart`)
- ✅ Use .autoDispose for screen-specific providers
- ✅ Use .family for parameterized providers
- ✅ Handle ALL AsyncValue states
- ❌ NEVER use handleError() in StreamProviders
- ✅ Use ErrorHandler.handle() for user-facing operations

#### **Domain Layer** (`lib/features/**/domain/**/*.dart`)
- ❌ NO Navigator, GoRouter, or context.go
- ❌ NO UI imports (Flutter widgets, Material, Cupertino)
- ❌ NO provider access
- ✅ Pure business logic only
- ✅ Accept dependencies as method parameters
- ✅ Accept locale as method parameter for currency formatting

#### **Data Layer - Repositories** (`lib/features/**/data/repositories/**/*.dart`)
- ✅ Implement repository interfaces from domain layer
- ✅ Map Firebase exceptions to AppException types
- ✅ Use timeout for write operations (5 seconds)
- ✅ Use offline-first pattern with Firestore
- ✅ New collections MUST be added to deleteUserData()

#### **Tests** (`**/*_test.dart`)
- ✅ Use test() for test descriptions (Dart convention)
- ✅ Use expect(actual, equals(expected)) for objects/arrays
- ✅ Mock ONLY side-effects (API, timers, logging, DB)
- ❌ NEVER mock pure functions
- ✅ ALL business logic MUST be tested
- ✅ Bug fixes MUST include regression tests
- ✅ Target ≥80% coverage for new code

#### **Localization Files** (`lib/l10n/**/*.arb`)
- ✅ ALL keys MUST be unique
- ✅ Include @keyName metadata with description
- ✅ Use proper placeholder syntax: {variableName}
- ✅ Run flutter gen-l10n after changes

#### **Documentation** (`docs/**/*.md`)
- ✅ Check for clarity, accuracy, completeness
- ✅ Flag references to deprecated APIs
- ✅ Verify code examples are correct
- ✅ Check for broken links

#### **CI/CD Workflows** (`.github/workflows/**/*.yml`)
- ✅ Pin actions to specific versions (not @main)
- ✅ Use secrets for sensitive data
- ✅ Add timeout-minutes to prevent hanging jobs
- ✅ Use concurrency to cancel outdated runs
- ✅ Verify permissions are minimal

#### **All Dart Files** (`**/*.dart`)
Comprehensive InvTrack Enterprise Rules enforcement:
- Architecture boundaries
- Code quality (complexity, file size)
- Riverpod best practices
- Localization requirements
- Privacy protection
- Multi-currency compliance
- Accessibility standards
- Security patterns
- Testing requirements
- Data lifecycle management

---

### **2. Path Filters (Excluded Files)**

CodeRabbit skips these files to focus on meaningful code:

**Generated Code:**
- `**/*.g.dart` (code generation)
- `**/*.freezed.dart` (freezed models)
- `**/generated/**` (generated directories)

**Build Artifacts:**
- `**/build/**`
- `**/.dart_tool/**`

**Dependencies:**
- `**/pubspec.lock`

**IDE Files:**
- `**/.idea/**`
- `**/.vscode/**`
- `**/.DS_Store`

**Assets:**
- `**/assets/**/*.png`
- `**/assets/**/*.jpg`
- `**/assets/**/*.svg`
- `**/assets/**/*.ttf`
- `**/assets/**/*.otf`

---

### **3. Tools Enabled**

CodeRabbit runs these linters automatically:

| Tool | Purpose |
|------|---------|
| **shellcheck** | Shell script linting |
| **markdownlint** | Markdown documentation linting |
| **yamllint** | YAML file linting |
| **actionlint** | GitHub Actions workflow linting |

---

### **4. Finishing Touches**

#### **Docstrings Generation**
- Enabled for all files
- Generates comprehensive docstrings for public APIs
- Includes parameter descriptions, return values, examples

#### **Unit Tests Generation**
- Enabled for all files
- Generates unit tests for business logic
- Covers edge cases and error paths
- Uses Dart test conventions

#### **Custom Recipes**

Five custom recipes for common review tasks:

1. **localization_check**
   - Check for hardcoded strings
   - Suggest ARB file entries
   - Verify unique keys

2. **privacy_check**
   - Verify PrivacyProtectionWrapper usage
   - Check for sensitive data in logs
   - Ensure analytics use ranges

3. **multi_currency_check**
   - Verify formatCompactCurrency() usage
   - Check original currency storage
   - Flag deprecated formatCompactIndian()

4. **accessibility_check**
   - Verify semantic labels
   - Check touch target sizes
   - Ensure color contrast

5. **architecture_check**
   - Verify clean architecture boundaries
   - Check for API calls in widgets
   - Check for navigation in domain layer

---

### **5. Knowledge Base**

CodeRabbit learns from your project documentation:

**Core Rules:**
- `.augment/rules/invtrack_rules.md`

**Technical Specifications:**
- `docs/InvTracker_TechSpec.md`
- `docs/InvTracker_PRD.md`

**Localization Guides:**
- `docs/LOCALIZATION.md`
- `docs/LOCALIZATION_QUICKSTART.md`
- `docs/CURRENCY_LOCALIZATION_GUIDE.md`

**Multi-Currency Implementation:**
- `docs/MULTI_CURRENCY_IMPLEMENTATION.md`
- `docs/MULTI_CURRENCY_PR_CHECKLIST.md`

**Accessibility:**
- `docs/ACCESSIBILITY.md`

**Feature Plans:**
- `docs/FIRE_NUMBER_FEATURE_PLAN.md`
- `docs/GOALS_FEATURE_PLAN.md`

**Project Overview:**
- `README.md`

**Additional Features:**
- Web search enabled for additional context
- Auto-learning from codebase patterns
- Scope: auto (learns from entire codebase)

---

## 🎛️ Configuration Options

### **Review Profile**

Current: `assertive` (more thorough reviews)

Options:
- `chill` - Less strict, fewer comments
- `assertive` - More thorough, detailed feedback

To change:
```yaml
reviews:
  profile: "chill"  # or "assertive"
```

### **Auto-Review Settings**

```yaml
reviews:
  auto_review:
    enabled: true   # Automatically review all PRs
    drafts: false   # Don't review draft PRs
```

### **Chat Settings**

```yaml
chat:
  auto_reply: true  # Auto-respond to questions
```

---

## 💬 Using CodeRabbit

### **Automatic Reviews**
- CodeRabbit reviews every PR automatically
- Comments appear within 1-2 minutes
- Re-reviews automatically when you push changes

### **Commands**

Use these commands in PR comments:

```bash
@coderabbit review              # Trigger full review
@coderabbit explain             # Get explanation
@coderabbit how do I fix this?  # Ask for help
@coderabbit ignore              # Ignore suggestion
@coderabbit localization_check  # Run localization recipe
@coderabbit privacy_check       # Run privacy recipe
@coderabbit multi_currency_check # Run multi-currency recipe
@coderabbit accessibility_check # Run accessibility recipe
@coderabbit architecture_check  # Run architecture recipe
```

---

## 📊 What CodeRabbit Reviews

### **Architecture**
- Clean architecture boundaries (UI → State → Domain → Data)
- No API calls in widgets
- No navigation in domain layer
- No business logic in UI

### **Code Quality**
- Flutter analyze compliance (zero errors/warnings)
- Cyclomatic complexity <15 per 100 lines
- File size limits (screens ≤500 lines, widgets ≤300 lines)
- Const constructor usage
- Resource disposal

### **Riverpod**
- ref.watch in build methods
- ref.read in callbacks
- AsyncValue state handling
- Provider disposal

### **Localization**
- All strings in ARB files
- No hardcoded strings
- Locale-aware formatting
- Currency formatting with locale

### **Privacy**
- PrivacyProtectionWrapper for financial data
- No sensitive data in logs/analytics
- Analytics use ranges, not exact amounts

### **Multi-Currency**
- formatCompactCurrency() with locale parameter
- Original currency stored with amounts
- No deprecated formatCompactIndian() calls

### **Accessibility**
- Semantic labels on images
- Touch targets ≥44dp
- Color contrast 4.5:1 minimum
- Screen reader compatibility

### **Security**
- No hardcoded secrets/API keys
- No print statements in production
- Input validation
- Data sanitization

### **Testing**
- Bug fixes include regression tests
- Business logic is tested
- ≥80% coverage for new code
- Proper test structure

### **Data Lifecycle**
- New storage in deleteUserData()
- Export/import services updated
- Firestore security rules added

---

## 🔧 Customization

### **Add New Path Instructions**

Edit `.coderabbit.yaml`:

```yaml
reviews:
  path_instructions:
    - path: "lib/my_feature/**/*.dart"
      instructions: |
        Your custom instructions here.
```

### **Add New Custom Recipe**

```yaml
reviews:
  finishing_touches:
    custom:
      - name: "my_custom_check"
        instructions: |
          Your custom check instructions here.
```

### **Add New Documentation**

```yaml
knowledge_base:
  code_guidelines:
    filePatterns:
      - "docs/MY_NEW_GUIDE.md"
```

---

## ✅ Benefits

1. **Comprehensive Coverage** - Reviews all aspects of InvTrack Enterprise Rules
2. **Context-Aware** - Understands your project documentation and patterns
3. **Consistent** - Applies same standards across all PRs
4. **Educational** - Teaches best practices through feedback
5. **Time-Saving** - Catches issues before human review
6. **Customizable** - Tailored to InvTrack's specific needs

---

## 📚 Resources

- **CodeRabbit Docs:** https://docs.coderabbit.ai/
- **Configuration Reference:** https://docs.coderabbit.ai/reference/configuration
- **Path Instructions:** https://docs.coderabbit.ai/configuration/path-instructions
- **InvTrack Rules:** `.augment/rules/invtrack_rules.md`

---

*Last Updated: 2026-03-10*
*Configuration Version: 2.0 (Comprehensive)*

