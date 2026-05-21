# Jules AI Crash Fix - Quick Setup Guide

**⚡ Get automated crash fixing in 10 minutes**

---

## Prerequisites

✅ Firebase Crashlytics already configured (InvTrack ✅)  
✅ GitHub repository (InvTrack ✅)  
✅ Google account with access to Jules AI

---

## Step 1: Generate Jules API Key (2 minutes)

1. Visit https://jules.google.com/settings
2. Sign in with your Google account
3. Navigate to **API Keys** section
4. Click **Generate New Key**
5. **Copy the key** (format: `AQ.xxxxxxxxxxxx`)

⚠️ **SECURITY:**
- **DO NOT commit this key to Git**
- **Never share API keys** in chat, logs, or public places
- If a key is exposed, revoke it immediately and generate a new one
- Keep API keys stored only in GitHub Secrets

---

## Step 2: Connect Repository to Jules (2 minutes)

1. Visit https://jules.google.com
2. Click **Connect Repository**
3. Install **Jules GitHub App** on InvTrack repository
4. Authorize access

This creates a "Source" that the API will use.

---

## Step 3: Get Your Jules Source Name (1 minute)

Run this command (replace `YOUR_API_KEY` with your new key):

```bash
curl -H "x-goog-api-key: YOUR_API_KEY" \
  https://jules.googleapis.com/v1alpha/sources | jq
```

**Find your repository** in the response and copy the **full `name`** value.

Example response:
```json
{
  "sources": [
    {
      "name": "sources/github-rkamalapuram-invtrack",
      "id": "github-rkamalapuram-invtrack",
      ...
    }
  ]
}
```

Copy: `sources/github-rkamalapuram-invtrack`

---

## Step 4: Generate Firebase CI Token (2 minutes)

```bash
# Install Firebase CLI (if not installed)
npm install -g firebase-tools

# Authenticate
firebase login

# Generate CI token
firebase login:ci
```

**Copy the token** displayed at the end.

---

## Step 5: Get Firebase App ID (1 minute)

1. Go to https://console.firebase.google.com/project/invtracker-b19d1
2. Click **Settings** (gear icon) → **Project Settings**
3. Scroll to **Your apps** section
4. Find **InvTrack (Android)** app
5. Copy the **App ID** (format: `1:123456789:android:abc123def456`)

---

## Step 6: Add GitHub Secrets (2 minutes)

1. Go to your InvTrack GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each:

| Secret Name | Value | Where You Got It |
|-------------|-------|------------------|
| `JULES_API_KEY` | `AQ.xxxxxxxxxxxx` | Step 1 (NEW key) |
| `JULES_SOURCE_NAME` | `sources/github-xxx-invtrack` | Step 3 |
| `FIREBASE_TOKEN` | Token from `firebase login:ci` | Step 4 |
| `FIREBASE_APP_ID` | `1:123456789:android:abc123` | Step 5 |

---

## Step 7: Test the Workflow (1 minute)

1. Go to **Actions** tab in GitHub
2. Select **Jules AI Crash Fix Automation** workflow
3. Click **Run workflow**
4. Set parameters:
   - **crash_limit:** 3 (test with fewer crashes)
   - **min_affected_users:** 1 (lower threshold for testing)
5. Click **Run workflow** button

---

## What Happens Next?

The workflow will:

1. ✅ Fetch top 3 crashes from Firebase Crashlytics
2. ✅ Create Jules AI sessions for each crash
3. ✅ Jules analyzes crashes and generates fixes
4. ✅ Creates pull requests with fixes + tests
5. ✅ Posts summary issue with PR links

**Timeline:** 
- First run: 15-30 minutes (Jules analyzes crashes)
- Daily runs: Automatic at 9 AM UTC

---

## Reviewing PRs

When Jules creates a PR:

1. **Review the changes:**
   - Root cause analysis
   - Fix implementation
   - Tests added

2. **Run tests locally:**
   ```bash
   flutter test
   flutter analyze
   ```

3. **Approve and merge** when satisfied

---

## 🎉 You're Done!

Jules AI will now automatically:
- ✅ Monitor crashes daily
- ✅ Generate fixes with tests
- ✅ Create pull requests
- ✅ Follow InvTrack coding standards

---

## Next Steps

- **Read full guide:** [JULES_CRASH_FIX_AUTOMATION.md](./JULES_CRASH_FIX_AUTOMATION.md)
- **Monitor workflow:** GitHub Actions tab
- **Review summary issues:** Check for PRs created
- **Track crash metrics:** Firebase Crashlytics Console

---

## Security Reminders

🔒 **Important:**
1. ✅ **Revoke the exposed API key** immediately
2. ✅ Keep new API key in GitHub Secrets only
3. ✅ Never commit credentials to Git
4. ✅ Rotate keys every 90 days
5. ✅ Review all automated PRs before merging

---

## Troubleshooting

### Workflow fails at "Fetch Crashlytics"
- ✅ Verify `FIREBASE_TOKEN` is valid
- ✅ Run `firebase projects:list --token YOUR_TOKEN` locally

### Workflow fails at "Create Jules Sessions"
- ✅ Verify `JULES_API_KEY` is valid
- ✅ Verify `JULES_SOURCE_NAME` is correct
- ✅ Check repository is connected in Jules web app

### No PRs created
- ✅ Check Jules dashboard: https://jules.google.com
- ✅ Review session URLs in summary issue
- ✅ May require manual intervention for complex crashes

---

**Setup Time:** ~10 minutes  
**First Run Time:** ~15-30 minutes  
**Daily Automation:** Runs at 9 AM UTC automatically

**Need Help?** See [JULES_CRASH_FIX_AUTOMATION.md](./JULES_CRASH_FIX_AUTOMATION.md) for detailed troubleshooting.
