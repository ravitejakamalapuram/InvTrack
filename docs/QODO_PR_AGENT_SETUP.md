# Qodo PR-Agent Setup (Optional Backup)

## 📌 When to Use This

Use Qodo PR-Agent if:
- ✅ You exceed CodeRabbit's 75 PR/month limit
- ✅ You want unlimited free reviews
- ✅ You want a self-hosted solution
- ✅ You want to use free AI models (DeepSeek, Groq, Ollama)

**Cost:** FREE (unlimited)

---

## 🚀 Quick Setup (15 minutes)

### **Step 1: Get Free AI API Key**

**Option A: DeepSeek (Recommended)**
1. Go to: https://platform.deepseek.com/
2. Sign up (free tier: 10M tokens/day)
3. Create API key
4. Copy the key

**Option B: Groq (Faster)**
1. Go to: https://console.groq.com/
2. Sign up (free tier: 14,400 requests/day)
3. Create API key
4. Copy the key

**Option C: Ollama (Fully Local)**
1. Install: https://ollama.ai/
2. Run: `ollama pull deepseek-coder`
3. No API key needed (runs on your machine)

---

### **Step 2: Add API Key to GitHub Secrets**

1. Go to: **Settings → Secrets and variables → Actions**
2. Click: **New repository secret**
3. Name: `DEEPSEEK_API_KEY` (or `GROQ_API_KEY`)
4. Value: Paste your API key
5. Click: **Add secret**

---

### **Step 3: Create Workflow File**

Create: `.github/workflows/pr-agent-review.yml`

```yaml
name: "PR: AI Review (PR-Agent)"

on:
  pull_request:
    types: [opened, ready_for_review, synchronize]

permissions:
  contents: read
  pull-requests: write
  issues: write

concurrency:
  group: pr-agent-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  pr-agent-review:
    name: AI Code Review (Qodo)
    runs-on: self-hosted
    if: github.event.pull_request.draft == false
    
    steps:
      - uses: actions/checkout@v4
      
      - name: PR Agent Review
        uses: Codium-ai/pr-agent@v0.24
        env:
          # Use DeepSeek (free) or Groq (free)
          OPENAI_KEY: ${{ secrets.DEEPSEEK_API_KEY }}
          OPENAI_API_BASE: "https://api.deepseek.com"
          # Or for Groq:
          # OPENAI_KEY: ${{ secrets.GROQ_API_KEY }}
          # OPENAI_API_BASE: "https://api.groq.com/openai/v1"
          
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          
          # Model selection
          MODEL: "deepseek-chat"
          # Or for Groq: "llama-3.1-70b-versatile"
          
          # PR-Agent configuration
          PR_REVIEWER.REQUIRE_ALL_THRESHOLDS_FOR_TESTS: "true"
          PR_REVIEWER.REQUIRE_FOCUSED_REVIEW: "true"
          PR_REVIEWER.REQUIRE_SECURITY_REVIEW: "true"
          PR_REVIEWER.REQUIRE_ESTIMATE_EFFORT_TO_REVIEW: "true"
          
          # InvTrack specific instructions
          PR_REVIEWER.EXTRA_INSTRUCTIONS: |
            Review against InvTrack Enterprise Rules:
            - Verify clean architecture: UI → State → Domain → Data
            - Check for API calls in widgets (should be in repositories)
            - Check for navigation in domain layer (should be in presentation)
            - Verify all AsyncValue states are handled (data, loading, error)
            - Check for hardcoded strings (should be in ARB files)
            - Verify currency formatting uses formatCompactCurrency with locale
            - Check for privacy protection on financial data (PrivacyProtectionWrapper)
            - Verify test coverage for business logic
            - Check for ref.read in build methods (should use ref.watch)
            - Verify proper disposal of controllers and subscriptions
            - Check file size limits: screens ≤500 lines, widgets ≤300 lines
```

---

### **Step 4: Test It**

1. Create a test PR
2. PR-Agent will automatically review it
3. You'll see comments from `github-actions[bot]`

---

## 🎛️ Configuration Options

### **Using Ollama (Local, No API Key)**

If you want to run AI locally on your self-hosted runner:

```yaml
env:
  # No API key needed
  OPENAI_API_BASE: "http://localhost:11434/v1"
  MODEL: "deepseek-coder"
  # Make sure Ollama is running on your self-hosted runner
```

### **Adjust Review Strictness**

```yaml
env:
  PR_REVIEWER.REQUIRE_SCORE_REVIEW: "true"  # Add code quality score
  PR_REVIEWER.REQUIRE_TESTS_REVIEW: "true"  # Review test coverage
  PR_REVIEWER.INLINE_CODE_COMMENTS: "true"  # Add inline suggestions
```

---

## 💬 Using PR-Agent

### **Commands in PR Comments:**

```bash
/review          # Trigger full review
/describe        # Generate PR description
/improve         # Suggest code improvements
/ask "question"  # Ask questions about the code
/update_changelog # Update CHANGELOG.md
```

### **Example:**

```
/review --focus security,performance
```

---

## 📊 Comparison: CodeRabbit vs PR-Agent

| Feature | CodeRabbit | Qodo PR-Agent |
|---------|-----------|---------------|
| **Cost** | Free (75 PR/mo) | Free (unlimited) |
| **Setup** | 5 min | 15 min |
| **AI Quality** | Excellent | Good |
| **Customization** | Good | Excellent |
| **Maintenance** | None | Low |
| **API Key** | Not needed | Needed (free options) |
| **Self-hosted** | No | Yes |

---

## 🔄 Using Both Together

You can run both CodeRabbit AND PR-Agent:

**Benefits:**
- CodeRabbit: Primary reviewer (better AI)
- PR-Agent: Backup/supplement (unlimited)
- Get multiple perspectives on code

**How:**
- Both will comment on PRs independently
- You get 2 AI reviews for free!

---

## 🆘 Troubleshooting

### **PR-Agent Not Running:**

1. **Check API key:**
   - Verify secret is named correctly
   - Test API key manually

2. **Check workflow file:**
   - Ensure proper indentation (YAML)
   - Verify `OPENAI_API_BASE` URL is correct

3. **Check self-hosted runner:**
   - Ensure runner is online
   - Check runner logs

### **API Rate Limits:**

If you hit rate limits:

1. **Switch to different provider:**
   - DeepSeek → Groq
   - Or use Ollama (local, no limits)

2. **Reduce review frequency:**
   - Only review on `ready_for_review` event
   - Skip draft PRs

---

## 📚 Resources

- **PR-Agent Docs:** https://pr-agent-docs.codium.ai/
- **DeepSeek API:** https://platform.deepseek.com/
- **Groq API:** https://console.groq.com/
- **Ollama:** https://ollama.ai/

---

## ✅ Summary

**Current Setup:**
- ✅ CodeRabbit (primary, installed)
- ⏸️ PR-Agent (optional, not installed yet)

**When to add PR-Agent:**
- If you exceed 75 PR/month
- If you want unlimited reviews
- If you want self-hosted solution

**Setup time:** 15 minutes
**Cost:** $0/month

---

*Last Updated: 2026-03-10*

