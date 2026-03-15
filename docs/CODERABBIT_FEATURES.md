# 🤖 CodeRabbit Features Guide for InvTrack

**Status:** ✅ **FREE FOREVER** (InvTrack is open source)

All CodeRabbit Pro features are available at no cost for public repositories!

---

## 🎯 Quick Start

### **In Every PR, You'll See:**

1. **Automated Review** - CodeRabbit reviews all changes automatically
2. **Finishing Touches** - Checkboxes to auto-fix common issues
3. **Chat Interface** - Ask CodeRabbit questions with `@coderabbitai`

---

## 🛠️ Auto-Fix Tools (Finishing Touches)

These appear as **checkboxes** in PR comments. Check the box to apply fixes!

### **1. Localization Check** ✅
**What it does:**
- Scans for hardcoded strings
- Suggests ARB file entries
- Generates localization code

**When to use:**
- After adding new UI text
- Before merging UI changes

**How to use:**
```
☐ localization_check: Commit on current branch
☐ localization_check: Create PR
```

---

### **2. Privacy Check** ✅
**What it does:**
- Finds financial data without `PrivacyProtectionWrapper`
- Checks for sensitive data in logs/analytics
- Ensures analytics use ranges (not exact amounts)

**When to use:**
- After adding new financial displays
- Before merging investment/goal features

**How to use:**
```
☐ privacy_check: Commit on current branch
☐ privacy_check: Create PR
```

---

### **3. Multi-Currency Check** ✅
**What it does:**
- Validates `formatCompactCurrency()` usage with locale
- Checks original currency storage
- Detects deprecated `formatCompactIndian()` calls

**When to use:**
- After adding currency displays
- Before merging financial features

**How to use:**
```
☐ multi_currency_check: Commit on current branch
☐ multi_currency_check: Create PR
```

---

### **4. Accessibility Check** ✅
**What it does:**
- Finds images without semantic labels
- Checks touch target sizes (≥44dp)
- Validates color contrast (4.5:1 minimum)

**When to use:**
- After adding new UI components
- Before merging widget changes

**How to use:**
```
☐ accessibility_check: Commit on current branch
☐ accessibility_check: Create PR
```

---

### **5. Architecture Check** ✅
**What it does:**
- Detects API calls in widgets
- Finds navigation in domain layer
- Validates clean architecture boundaries

**When to use:**
- After refactoring
- Before merging new features

**How to use:**
```
☐ architecture_check: Commit on current branch
☐ architecture_check: Create PR
```

---

### **6. Generate Unit Tests** 🧪
**What it does:**
- AI generates test cases for new code
- Covers edge cases and error scenarios
- Follows Dart testing conventions

**When to use:**
- After adding new business logic
- When test coverage is low

**How to use:**
```
☐ Generate unit tests: Post copyable unit tests in comment
☐ Generate unit tests: Commit on current branch
☐ Generate unit tests: Create PR
```

---

### **7. Generate Docstrings** 📝
**What it does:**
- AI generates documentation for public APIs
- Includes parameter descriptions
- Adds usage examples

**When to use:**
- After adding new public methods
- When documentation is missing

**How to use:**
```
☐ Generate docstrings: Commit on current branch
```

---

## 💬 Chat Commands

Ask CodeRabbit questions by mentioning `@coderabbitai` in PR comments:

### **Common Commands:**

```bash
@coderabbitai help
# Shows all available commands

@coderabbitai review
# Re-run the full review

@coderabbitai generate tests
# Generate unit tests for this PR

@coderabbitai fix localization
# Run localization check and suggest fixes

@coderabbitai explain this code
# Explain what the code does

@coderabbitai suggest improvements
# Get optimization suggestions

@coderabbitai create coding plan
# Generate step-by-step implementation plan
```

### **Advanced Commands:**

```bash
@coderabbitai generate sequence diagram
# Create mermaid diagram for complex flows

@coderabbitai check security
# Run security analysis

@coderabbitai check performance
# Analyze performance issues

@coderabbitai compare with main
# Show differences from main branch
```

---

## 📊 Reports & Analytics

### **Sprint Summary Report**
Get a summary of all PRs merged in a sprint:

```bash
@coderabbitai generate sprint report from 2024-01-01 to 2024-01-15
```

**Includes:**
- Total PRs merged
- Lines of code changed
- Top contributors
- Common issues found
- Review turnaround times

---

### **Code Quality Report**
Track quality metrics over time:

```bash
@coderabbitai generate quality report
```

**Includes:**
- Test coverage trends
- Complexity metrics
- Technical debt accumulation
- Issue resolution rate

---

## 🎓 Knowledge Base

CodeRabbit learns from your codebase and documentation:

### **What it learns:**
- ✅ InvTrack Enterprise Rules (`.augment/rules/invtrack_rules.md`)
- ✅ Technical specifications (`docs/InvTracker_TechSpec.md`)
- ✅ Localization guides (`docs/LOCALIZATION*.md`)
- ✅ Multi-currency implementation (`docs/MULTI_CURRENCY*.md`)
- ✅ Code patterns from existing code

### **How it helps:**
- Enforces project-specific rules
- Suggests fixes based on existing patterns
- References documentation in reviews
- Provides context-aware suggestions

---

## 🚀 Advanced Features

### **1. AST-Based Analysis** ✅
- Deeper code understanding
- More accurate suggestions
- Better refactoring recommendations

### **2. Code Context Awareness** ✅
- Understands relationships between files
- Suggests fixes based on usage patterns
- Detects breaking changes

### **3. Incremental Reviews** ✅
- Only reviews changed code
- Faster feedback
- More focused comments

### **4. Auto-Title Generation** ✅
- Generates PR titles from changes
- Follows conventional commit format
- Saves time on PR creation

### **5. Sequence Diagrams** ✅
- Visualizes complex flows
- Generates mermaid diagrams
- Helps understand multi-file interactions

---

## 📋 Best Practices

### **1. Use Auto-Fix Tools Early**
Run checks before requesting human review:
- ✅ Localization check (catch hardcoded strings)
- ✅ Privacy check (ensure wrappers)
- ✅ Architecture check (validate boundaries)

### **2. Generate Tests for New Code**
Use "Generate unit tests" for:
- New business logic
- Bug fixes (regression tests)
- Complex algorithms

### **3. Ask Questions**
Use `@coderabbitai` to:
- Understand complex code
- Get refactoring suggestions
- Learn best practices

### **4. Review CodeRabbit's Suggestions**
CodeRabbit is smart, but not perfect:
- ✅ Review all suggestions
- ✅ Verify auto-fixes before merging
- ✅ Provide feedback (helps it learn)

---

## 🎯 Workflow Example

### **Typical PR Flow:**

1. **Create PR** → CodeRabbit auto-reviews
2. **Check "Finishing Touches"** → Run relevant auto-fix tools
3. **Review suggestions** → Apply or dismiss
4. **Ask questions** → Use `@coderabbitai` for clarification
5. **Generate tests** → If coverage is low
6. **Merge** → All checks passed!

---

## 💡 Pro Tips

1. **Run multiple checks at once** - Check all relevant boxes
2. **Use "Create PR" for big fixes** - Keeps main PR clean
3. **Generate tests early** - Easier to fix issues before review
4. **Ask for explanations** - Learn from CodeRabbit's knowledge
5. **Review sprint reports** - Track team progress

---

## 🆘 Troubleshooting

### **CodeRabbit not responding?**
```bash
@coderabbitai ping
```

### **Want to re-run review?**
```bash
@coderabbitai review
```

### **Need help?**
```bash
@coderabbitai help
```

---

## 📚 Resources

- **CodeRabbit Docs:** https://docs.coderabbit.ai/
- **Configuration:** `.coderabbit.yaml`
- **InvTrack Rules:** `.augment/rules/invtrack_rules.md`

---

**Remember:** All these features are **FREE** because InvTrack is open source! 🎉

