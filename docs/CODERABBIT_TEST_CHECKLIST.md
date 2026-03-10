# CodeRabbit Test Checklist

## 🧪 Testing Your CodeRabbit Setup

Follow these steps to verify CodeRabbit is working correctly.

---

## ✅ Test 1: Create a Simple Test PR

### **Step 1: Create a test branch**

```bash
git checkout -b test/coderabbit-setup
```

### **Step 2: Make a simple change**

Create a test file with an intentional violation:

```bash
# Create a test file with architecture violation
cat > lib/test_coderabbit.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// This widget intentionally violates architecture rules
// to test CodeRabbit detection
class TestWidget extends StatelessWidget {
  const TestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // ❌ VIOLATION: API call in widget (should be in repository)
    final data = FirebaseFirestore.instance.collection('test').get();
    
    // ❌ VIOLATION: Hardcoded string (should be in ARB file)
    return Text('Hello World');
  }
}
EOF
```

### **Step 3: Commit and push**

```bash
git add lib/test_coderabbit.dart
git commit -m "test: CodeRabbit setup verification"
git push origin test/coderabbit-setup
```

### **Step 4: Create PR**

```bash
# Using GitHub CLI
gh pr create --title "Test: CodeRabbit Setup" --body "Testing CodeRabbit automated review"

# Or manually:
# Go to GitHub → Create Pull Request
```

### **Step 5: Wait for CodeRabbit**

- CodeRabbit should comment within 1-2 minutes
- Look for comments from `@coderabbit`

---

## 🔍 What CodeRabbit Should Detect

CodeRabbit should flag these violations:

### **1. Architecture Violation**
```
⚠️ Found FirebaseFirestore import in widget layer
Widgets should not directly access Firestore (violates clean architecture)
```

### **2. Localization Violation**
```
⚠️ Found hardcoded string: 'Hello World'
All user-facing strings must be in ARB files
```

### **3. Missing Error Handling**
```
⚠️ Firestore query without error handling
Should handle AsyncValue states (data, loading, error)
```

---

## ✅ Test 2: Interact with CodeRabbit

### **Ask a question:**

Comment on the PR:
```
@coderabbit How should I fix the architecture violation?
```

CodeRabbit should respond with suggestions.

### **Request re-review:**

After making changes:
```
@coderabbit review
```

---

## ✅ Test 3: Verify Configuration

### **Check CodeRabbit is using your config:**

1. Look for comments mentioning InvTrack Enterprise Rules
2. Verify it's checking architecture boundaries
3. Confirm it's flagging localization issues

### **Expected behavior:**

- ✅ Reviews automatically on PR creation
- ✅ Comments on specific lines with violations
- ✅ Provides actionable suggestions
- ✅ Responds to @coderabbit mentions
- ✅ Re-reviews after changes

---

## 🧹 Cleanup After Testing

### **Step 1: Close the test PR**

```bash
gh pr close test/coderabbit-setup --delete-branch

# Or manually:
# Go to PR → Close pull request → Delete branch
```

### **Step 2: Delete the test file**

```bash
git checkout main
git branch -D test/coderabbit-setup
rm lib/test_coderabbit.dart  # If it was merged
```

---

## 🎯 Success Criteria

CodeRabbit setup is successful if:

- ✅ CodeRabbit comments on PR within 2 minutes
- ✅ Detects architecture violations (Firestore in widget)
- ✅ Detects localization violations (hardcoded strings)
- ✅ Provides specific, actionable feedback
- ✅ Responds to @coderabbit commands
- ✅ References InvTrack Enterprise Rules

---

## 🆘 If CodeRabbit Doesn't Comment

### **Check 1: PR is not draft**
```bash
# Make sure PR is marked "Ready for review"
gh pr ready test/coderabbit-setup
```

### **Check 2: CodeRabbit has access**
1. Go to: https://github.com/settings/installations
2. Find: CodeRabbit
3. Verify: InvTrack repository is selected

### **Check 3: Manually trigger**
Comment on PR:
```
@coderabbit review
```

### **Check 4: Check CodeRabbit status**
1. Go to: https://app.coderabbit.ai/
2. Sign in with GitHub
3. Check dashboard for errors

---

## 📊 Expected Timeline

| Action | Time |
|--------|------|
| Create PR | Instant |
| CodeRabbit triggered | ~10 seconds |
| CodeRabbit analysis | ~30-60 seconds |
| CodeRabbit comments | ~1-2 minutes total |

---

## 🎉 Next Steps After Successful Test

1. **Delete test PR and branch** (cleanup)
2. **Start using CodeRabbit on real PRs**
3. **Review CodeRabbit feedback** and iterate
4. **Adjust `.coderabbit.yaml`** if needed (more/less strict)

---

## 📝 Notes

- CodeRabbit learns from your codebase over time
- First few reviews might be less accurate
- You can train CodeRabbit by accepting/rejecting suggestions
- CodeRabbit respects your `.coderabbit.yaml` configuration

---

*Last Updated: 2026-03-10*

