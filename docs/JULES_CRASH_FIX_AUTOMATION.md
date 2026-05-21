# Jules AI Crash Fix Automation

**Automated crash detection and fixing using Google's Jules AI coding agent**

---

## 📋 Overview

This automation integrates Firebase Crashlytics with Google's Jules AI to automatically:
1. **Fetch** top crashes from Firebase Crashlytics daily
2. **Analyze** crashes with Jules AI's coding agent
3. **Generate** fixes with comprehensive tests
4. **Create** pull requests automatically
5. **Report** results via GitHub issues

**Key Benefits:**
- ✅ Proactive crash fixing without manual intervention
- ✅ AI-generated fixes following InvTrack coding standards
- ✅ Comprehensive test coverage for all fixes
- ✅ Full transparency with GitHub PR reviews
- ✅ Reduced time from crash detection to fix deployment

---

## 🏗️ Architecture

```
┌─────────────────────┐
│  GitHub Actions     │ ← Scheduled (daily) or manual trigger
│  (Daily 9 AM UTC)   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Firebase Crashlytics│ ← Fetch top crashes via CLI/MCP
│  Top Issues API     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Filter & Format    │ ← Filter by user impact, format for Jules
│  Crash Data         │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Jules API          │ ← Create sessions with AUTO_CREATE_PR
│  Create Sessions    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Monitor Sessions   │ ← Poll until completion (30 min timeout)
│  (Poll every 60s)   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Jules Creates PRs  │ ← AI-generated fixes with tests
│  Automatically      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  GitHub Issue       │ ← Summary report with PR links
│  Summary Report     │
└─────────────────────┘
```

---

## 🔧 Setup Instructions

### Prerequisites

1. **Firebase Crashlytics configured** (already done ✅)
2. **Jules AI account** with API access
3. **GitHub repository connected** to Jules via web app

### Step 1: Generate Jules API Key

1. Go to [jules.google.com/settings](https://jules.google.com/settings)
2. Sign in with your Google account
3. Navigate to **API Keys** section
4. Click **Generate New Key**
5. Copy the API key (format: `AQ.xxxxxxxxxxxx`)

⚠️ **IMPORTANT:** Keep this key secure! Never commit it to Git.

### Step 2: Connect Repository to Jules

1. Visit [jules.google.com](https://jules.google.com)
2. Click **Connect Repository**
3. Install Jules GitHub App on your InvTrack repository
4. Authorize access

This creates a "Source" that the API can reference.

### Step 3: Get Your Jules Source Name

Run this command to get your source name:

```bash
curl -H "x-goog-api-key: YOUR_API_KEY" \
  https://jules.googleapis.com/v1alpha/sources
```

Look for your repository in the response. The source name will be like:
```json
{
  "name": "sources/github-owner-invtrack",
  "id": "github-owner-invtrack",
  ...
}
```

Copy the full `name` value (e.g., `sources/github-owner-invtrack`).

### Step 4: Generate Firebase CI Token

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Authenticate
firebase login

# Generate CI token
firebase login:ci
```

Copy the token that's displayed.

### Step 5: Get Firebase App ID

1. Go to [Firebase Console](https://console.firebase.google.com/project/invtracker-b19d1)
2. Navigate to **Project Settings** → **General**
3. Scroll to **Your apps** section
4. Find your Android app
5. Copy the **App ID** (format: `1:123456789:android:abc123def456`)

### Step 6: Configure GitHub Secrets

Add these secrets to your repository:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `JULES_API_KEY` | Your Jules API key | Step 1 above |
| `JULES_SOURCE_NAME` | Your Jules source name | Step 3 above |
| `FIREBASE_TOKEN` | Firebase CI token | Step 4 above |
| `FIREBASE_APP_ID` | Firebase app ID | Step 5 above |

**To add secrets:**
1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Click **New repository secret**
4. Add each secret above

---

## 🚀 Usage

### Automatic Daily Runs

The workflow runs automatically **every day at 9 AM UTC** to check for new crashes.

### Manual Trigger

Trigger the workflow manually with custom parameters:

1. Go to **Actions** tab in GitHub
2. Select **Jules AI Crash Fix Automation** workflow
3. Click **Run workflow**
4. Configure parameters:
   - **crash_limit**: Number of top crashes to analyze (1-10)
   - **min_affected_users**: Minimum users affected (default: 5)
   - **report_type**: `topIssues` or `topVersions`
5. Click **Run workflow**

### Workflow Parameters

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `crash_limit` | Number of crashes to process | 5 | 1, 3, 5, 10 |
| `min_affected_users` | Minimum users affected | 5 | Any number |
| `report_type` | Crashlytics report type | topIssues | topIssues, topVersions |

---

## 📊 What Happens During a Run

### Phase 1: Fetch Crashes (2-5 minutes)
- Authenticates with Firebase
- Fetches top crashes from Crashlytics
- Filters by minimum affected users
- Saves crash data to `crashlytics_data.json`

### Phase 2: Create Jules Sessions (1-2 minutes per crash)
- Creates a Jules AI session for each crash
- Provides detailed prompts with:
  - Crash details and stack trace
  - Requirements for fix (null checks, tests, etc.)
  - InvTrack coding standards (Riverpod, localization)
- Uses `AUTO_CREATE_PR` mode for automatic PR creation
- Rate-limited to 1 session every 2 seconds

### Phase 3: Monitor Sessions (up to 30 minutes)
- Polls each session every 60 seconds
- Tracks session states: QUEUED → PLANNING → IN_PROGRESS → COMPLETED
- Captures PR URLs when created
- Saves results to `session_results.json`

### Phase 4: Create Summary (1 minute)
- Generates summary report
- Creates GitHub issue with:
  - Statistics (PRs created, failed, timed out)
  - Links to all created PRs
  - Session URLs for manual review
- Labels issue with `automated`, `crashlytics`, `jules-ai`

---

## 🔍 Reviewing Generated PRs

When Jules creates a PR, it will:

✅ **Include in PR:**
- Root cause analysis of the crash
- Defensive code fix with null checks
- Comprehensive unit/widget tests
- InvTrack coding standards compliance
- Reference to Crashlytics issue ID

✅ **Review Checklist:**
- [ ] Fix addresses root cause
- [ ] No new analyzer warnings
- [ ] Tests cover edge cases
- [ ] Follows InvTrack architecture (Riverpod, clean architecture)
- [ ] Localization used correctly
- [ ] No hardcoded strings

✅ **Merge Process:**
1. Review PR code changes
2. Run tests locally if needed: `flutter test`
3. Check CI status
4. Approve PR
5. Merge via squash merge
6. Monitor for any regressions

---

## 📁 File Structure

```
.github/
├── workflows/
│   └── jules-crash-fix.yml         # Main workflow orchestration
├── scripts/
│   ├── fetch-crashlytics-data.sh   # Fetch crashes from Firebase
│   ├── create-jules-sessions.sh    # Create Jules AI sessions
│   ├── monitor-jules-sessions.sh   # Poll session status
│   └── create-summary-issue.sh     # Generate summary report

docs/
└── JULES_CRASH_FIX_AUTOMATION.md   # This documentation
```

### Generated Files (Per Run)

| File | Description |
|------|-------------|
| `crashlytics_data.json` | Crash data from Firebase |
| `jules_sessions.json` | Created Jules sessions |
| `session_results.json` | Final session results |
| `session_summary.md` | Summary report markdown |

---

## 🔧 Troubleshooting

### No Crashes Found

**Symptom:** Workflow shows "No crashes found meeting criteria"

**Solutions:**
- Lower `min_affected_users` parameter
- Check Firebase Crashlytics console for actual crashes
- Verify app is sending crash reports to Firebase

### Jules Session Failed

**Symptom:** Session status shows FAILED

**Solutions:**
- Review session URL in Jules dashboard
- Check if repository connection is still active
- Verify source name is correct in secrets

### PR Not Created

**Symptom:** Session completes but no PR

**Possible Reasons:**
- Jules determined fix not needed
- Complex crash requiring manual intervention
- Branch protection rules blocking automated PR

**Action:** Review session in Jules web app for details

### Authentication Errors

**Symptom:** Firebase or Jules API authentication fails

**Solutions:**
- Regenerate Firebase CI token: `firebase login:ci`
- Verify Jules API key is valid (check expiration)
- Update GitHub secrets with new values

---

## ⚙️ Configuration

### Adjusting Schedule

Edit `.github/workflows/jules-crash-fix.yml`:

```yaml
schedule:
  - cron: '0 9 * * *'  # Change time here (UTC)
```

Examples:
- `0 6 * * *` - 6 AM UTC daily
- `0 */6 * * *` - Every 6 hours
- `0 9 * * 1-5` - Weekdays only at 9 AM UTC

### Changing Timeout

Edit workflow file, update `MAX_WAIT_MINUTES`:

```yaml
env:
  MAX_WAIT_MINUTES: 30  # Increase if needed
```

### Filtering Crashes

Adjust in workflow dispatch inputs or modify `fetch-crashlytics-data.sh` to add custom filters.

---

## 📈 Monitoring and Metrics

### View Workflow Runs
- Go to **Actions** tab → **Jules AI Crash Fix Automation**
- Click on any run to see logs

### Download Artifacts
- Each run saves artifacts for 30 days
- Contains: crash data, session info, summary

### Track PR Merge Rate
- Review summary issues for PR links
- Track merge rate to gauge fix quality

---

## 🔒 Security Best Practices

✅ **Do:**
- Store all credentials in GitHub Secrets
- Rotate Jules API key every 90 days
- Review all automated PRs before merging
- Monitor workflow logs for suspicious activity

❌ **Don't:**
- Commit API keys to repository
- Auto-merge PRs without review
- Expose Firebase tokens in logs
- Share API keys across projects

---

## 📚 Related Documentation

| Document | Purpose |
|----------|---------|
| [FIREBASE_CRASHLYTICS_MCP_SETUP.md](./FIREBASE_CRASHLYTICS_MCP_SETUP.md) | Firebase MCP tools setup |
| [CRASHLYTICS_AUTOMATION.md](./CRASHLYTICS_AUTOMATION.md) | Manual crash monitoring |
| [InvTrack Enterprise Rules](../.augment/rules/invtrack_rules.md) | Coding standards |

---

## 🔗 External Resources

- **Jules API Docs:** https://jules.google/docs/api/reference/
- **Jules Web App:** https://jules.google.com
- **Firebase Crashlytics:** https://firebase.google.com/docs/crashlytics
- **GitHub Actions:** https://docs.github.com/actions

---

## 🆘 Support

For issues or questions:
1. Check [Troubleshooting](#-troubleshooting) section above
2. Review workflow logs in GitHub Actions
3. Check Jules session in web app for detailed errors
4. Create a GitHub issue with `jules-ai` label

---

**Last Updated:** 2026-05-21  
**Maintainer:** InvTrack DevOps  
**Jules API Version:** v1alpha
