# 🤖 Jules AI Crash Fix - Setup Checklist

**Quick reference for enabling automated crash fixing**

---

## ⚠️ CRITICAL - Security First

- [ ] **Revoke any exposed API keys** at https://jules.google.com/settings
  - If you shared API keys in chat/logs, delete them immediately
  - Never reuse exposed keys
  - Generate fresh keys for production use

---

## 📋 Pre-Setup Verification

- [x] Firebase Crashlytics configured ✅
- [x] GitHub repository (InvTrack) ✅
- [x] Workflow files created ✅
- [x] Documentation complete ✅
- [ ] Google account ready
- [ ] GitHub repository admin access

---

## 🔧 Setup Steps (10 minutes)

### Step 1: Jules API Key
- [ ] Visit https://jules.google.com/settings
- [ ] Sign in with Google account
- [ ] Click **Generate New Key** in API Keys section
- [ ] Copy key (format: `AQ.xxxxxxxxxxxx`)
- [ ] **Save it securely** (you'll need it in Step 6)

### Step 2: Connect Repository
- [ ] Visit https://jules.google.com
- [ ] Click **Connect Repository**
- [ ] Install Jules GitHub App on InvTrack
- [ ] Authorize access
- [ ] ✅ Confirm repository shows in Jules dashboard

### Step 3: Get Source Name
- [ ] Run command (replace with your API key):
  ```bash
  curl -H "x-goog-api-key: YOUR_NEW_API_KEY" \
    https://jules.googleapis.com/v1alpha/sources | jq
  ```
- [ ] Find your repository in response
- [ ] Copy full `name` value (e.g., `sources/github-owner-invtrack`)
- [ ] **Save it** (you'll need it in Step 6)

### Step 4: Firebase CI Token
- [ ] Ensure Firebase CLI installed: `firebase --version`
  - If not: `npm install -g firebase-tools`
- [ ] Run: `firebase login`
- [ ] Run: `firebase login:ci`
- [ ] Copy the token displayed
- [ ] **Save it securely** (you'll need it in Step 6)

### Step 5: Firebase App ID
- [ ] Go to https://console.firebase.google.com/project/invtracker-b19d1
- [ ] Click Settings → Project Settings
- [ ] Scroll to **Your apps** section
- [ ] Find **InvTrack (Android)**
- [ ] Copy **App ID** (format: `1:123456789:android:abc123`)
- [ ] **Save it** (you'll need it in Step 6)

### Step 6: Configure GitHub Secrets
- [ ] Go to GitHub repository: Settings → Secrets and variables → Actions
- [ ] Click **New repository secret** and add:

  **JULES_API_KEY**
  - [ ] Paste your new Jules API key from Step 1
  - [ ] ✅ Secret added

  **JULES_SOURCE_NAME**
  - [ ] Paste source name from Step 3 (e.g., `sources/github-xxx-invtrack`)
  - [ ] ✅ Secret added

  **FIREBASE_TOKEN**
  - [ ] Paste token from Step 4
  - [ ] ✅ Secret added

  **FIREBASE_APP_ID**
  - [ ] Paste app ID from Step 5 (e.g., `1:123456789:android:abc123`)
  - [ ] ✅ Secret added

### Step 7: Test Workflow
- [ ] Go to GitHub → **Actions** tab
- [ ] Select **Jules AI Crash Fix Automation**
- [ ] Click **Run workflow**
- [ ] Set parameters:
  - crash_limit: **3** (start small)
  - min_affected_users: **1** (lower threshold for testing)
  - report_type: **topIssues**
- [ ] Click **Run workflow** button
- [ ] ✅ Workflow started

---

## ✅ Verification Steps

### Immediate (During First Run)
- [ ] Workflow appears in Actions tab
- [ ] "Fetch Crashlytics Data" step succeeds
- [ ] "Create Jules Sessions" step succeeds
- [ ] Check workflow logs for session IDs

### After 15-30 Minutes
- [ ] Workflow completes successfully
- [ ] GitHub issue created with summary
- [ ] Pull requests created (if crashes found)
- [ ] Session URLs accessible in Jules dashboard

### Review First PR
- [ ] PR contains fix for crash
- [ ] Tests added for regression prevention
- [ ] Code follows InvTrack standards
- [ ] Run `flutter test` locally
- [ ] Run `flutter analyze` locally
- [ ] ✅ Approve and merge when satisfied

---

## 📊 Post-Setup Monitoring

### Daily Automation
- [ ] Workflow scheduled for 9 AM UTC daily
- [ ] Check Actions tab for daily runs
- [ ] Review summary issues created
- [ ] Merge automated PRs regularly

### Weekly Review
- [ ] Check crash-free user percentage in Firebase
- [ ] Review merged PRs from Jules
- [ ] Monitor workflow success rate
- [ ] Adjust parameters if needed

### Monthly Audit
- [ ] Review total crashes fixed
- [ ] Analyze fix quality
- [ ] Update workflow configuration
- [ ] Rotate API keys (every 90 days)

---

## 🔍 Troubleshooting

### Workflow Fails - Fetch Crashlytics
- [ ] Verify `FIREBASE_TOKEN` in GitHub secrets
- [ ] Test locally: `firebase projects:list --token YOUR_TOKEN`
- [ ] Regenerate token if expired: `firebase login:ci`

### Workflow Fails - Create Jules Sessions
- [ ] Verify `JULES_API_KEY` in GitHub secrets
- [ ] Verify `JULES_SOURCE_NAME` format
- [ ] Check repository connected in Jules web app
- [ ] Test API key: `curl -H "x-goog-api-key: KEY" https://jules.googleapis.com/v1alpha/sources`

### No PRs Created
- [ ] Check summary issue for session URLs
- [ ] Visit Jules dashboard to review sessions
- [ ] Verify crashes actually exist in Crashlytics
- [ ] Check session status (may need manual review)

---

## 📚 Quick Documentation Links

- **Quick Setup:** `docs/JULES_QUICK_SETUP.md`
- **Full Guide:** `docs/JULES_CRASH_FIX_AUTOMATION.md`
- **Implementation:** `docs/JULES_IMPLEMENTATION_SUMMARY.md`
- **Workflow README:** `.github/workflows/README.md`

---

## 🎯 Success Criteria

✅ **Setup Complete When:**
- [ ] All 4 GitHub secrets configured
- [ ] Test workflow run succeeds
- [ ] At least 1 summary issue created
- [ ] Jules sessions visible in dashboard
- [ ] No authentication errors in logs

✅ **Automation Working When:**
- [ ] Daily workflow runs automatically
- [ ] PRs created for crashes
- [ ] Fixes follow InvTrack standards
- [ ] Tests pass consistently
- [ ] Crash-free percentage improving

---

## 🔐 Security Checklist

- [ ] Exposed API key revoked
- [ ] New API key stored only in GitHub Secrets
- [ ] API key not committed to Git
- [ ] All secrets use "Repository secrets" (not environment)
- [ ] No secrets in workflow logs
- [ ] API key rotation scheduled (90 days)

---

## 📈 Expected Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| Setup (Steps 1-7) | 10 minutes | ⏳ In Progress |
| First workflow run | 15-30 minutes | ⏳ Pending |
| First PR review | 5-10 minutes | ⏳ Pending |
| Daily automation | Ongoing | ⏳ Will start after setup |

---

## ✅ Final Checklist

- [ ] All setup steps completed
- [ ] Test workflow succeeded
- [ ] First PR reviewed and merged
- [ ] Daily schedule enabled
- [ ] Documentation bookmarked
- [ ] Team notified about automation

---

**Setup Started:** _____________  
**Setup Completed:** _____________  
**First PR Merged:** _____________  
**Status:** 🎯 Ready to enable

---

**Need Help?**
- See `docs/JULES_QUICK_SETUP.md` for step-by-step guide
- See `docs/JULES_CRASH_FIX_AUTOMATION.md` for troubleshooting
- Check workflow logs in GitHub Actions tab
