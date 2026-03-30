# Crashlytics Automation

**Automated crash monitoring and PR generation via GitHub Actions**

---

## Overview

The InvTrack project includes an automated Crashlytics monitoring system that:
- ✅ Checks Firebase Crashlytics **every 6 hours**
- ✅ Detects new crashes automatically
- ✅ Creates PR with crash report when issues found
- ✅ Provides actionable insights for debugging

---

## How It Works

### 1. **Scheduled Monitoring**
GitHub Actions workflow runs every 6 hours:
- **Schedule**: `0 */6 * * *` (00:00, 06:00, 12:00, 18:00 UTC)
- **Manual trigger**: Can also be run on-demand via GitHub UI

### 2. **Crash Detection**
Script checks Firebase Crashlytics for:
- New crashes in the last 6 hours
- Crash frequency and user impact
- Stack traces and error messages

### 3. **Automated PR Creation**
If crashes detected:
- Creates branch: `crashlytics/auto-report-YYYYMMDD-HHMMSS`
- Generates crash report in `docs/crashlytics-reports/`
- Opens PR with:
  - Summary of crashes
  - Link to Firebase Console
  - Action items checklist

### 4. **No Crashes**
If no crashes found:
- Logs success message
- No PR created
- Workflow completes silently

---

## Setup Requirements

### 1. **Firebase Token** (Required)

The workflow needs a Firebase CI token to authenticate with Firebase.

**Generate token:**
```bash
firebase login:ci
```

This will output a token like: `1//abcd1234...`

**Add to GitHub Secrets:**
1. Go to: `Settings` → `Secrets and variables` → `Actions`
2. Click `New repository secret`
3. Name: `FIREBASE_TOKEN`
4. Value: `<paste token from above>`
5. Click `Add secret`

### 2. **GitHub Token** (Auto-configured)

The `${{ github.token }}` is automatically provided by GitHub Actions.
No manual setup required.

---

## Usage

### Automatic Monitoring

The workflow runs automatically every 6 hours. No action required.

### Manual Trigger

To run the workflow manually:

1. Go to: `Actions` → `Crashlytics Monitor`
2. Click `Run workflow`
3. Select branch (usually `main`)
4. Click `Run workflow` button

---

## Workflow Files

| File | Purpose |
|------|---------|
| `.github/workflows/crashlytics-monitor.yml` | Main GitHub Action workflow |
| `.github/scripts/check-crashlytics.sh` | Crash detection script |
| `docs/CRASHLYTICS_AUTOMATION.md` | This documentation |

---

## Example PR

When crashes are detected, the automation creates a PR like this:

**Title**: 🚨 Crashlytics: New Crashes Detected

**Body**:
```markdown
## Automated Crash Report

**Period**: Last 6 hours  
**Crashes Found**: 3 issues affecting 12 users

### Summary

1. NullPointerException in LoginScreen.dart:142 (8 users)
2. StateError in InvestmentProvider:89 (3 users)  
3. FormatException in CurrencyUtils:56 (1 user)

### Firebase Console

View detailed reports: [Firebase Crashlytics Console](https://console.firebase.google.com/project/invtracker-b19d1/crashlytics)

### Action Items

- [ ] Review crash stack traces
- [ ] Identify root causes
- [ ] Create bug fix PRs
- [ ] Add regression tests
```

---

## Crash Report Format

Generated reports are stored in `docs/crashlytics-reports/CRASH_REPORT_YYYYMMDD.md`:

```markdown
# Crashlytics Automated Report

**Generated**: 2026-03-30 12:00:00 UTC
**Period**: Last 6 hours
**Project**: invtracker-b19d1

## Summary

- Total crashes: 3
- Affected users: 12
- App versions: 3.54.11

## Top Issues

### 1. NullPointerException in LoginScreen.dart
- **Users affected**: 8
- **First seen**: 2026-03-30 08:30:00 UTC
- **Stack trace**: [View in Firebase](...)

## Action Required

1. Review crash details in Firebase Console
2. Prioritize critical crashes (high user impact)
3. Create bug fix PRs for top issues
4. Add investigation notes to Crashlytics
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **Workflow fails: "Authentication failed"** | Regenerate `FIREBASE_TOKEN` secret |
| **No PR created despite crashes** | Check Firebase Console manually |
| **Script permission denied** | Workflow includes `chmod +x` step |
| **MCP unavailable** | Script falls back to manual check instructions |

---

## Limitations & Future Enhancements

### Current Limitations
- ⚠️ Requires manual FIREBASE_TOKEN rotation (tokens can expire)
- ⚠️ Basic crash detection (placeholder implementation)
- ⚠️ Relies on Firebase MCP availability

### Planned Enhancements
1. **Smart Filtering**: Ignore known/resolved crashes
2. **Severity Classification**: Auto-prioritize critical crashes
3. **Slack/Email Notifications**: Alert team immediately
4. **Auto-linking to Jira**: Create bug tickets automatically
5. **Historical Trending**: Compare crash rates week-over-week

---

## Firebase Console

**Manual check**: https://console.firebase.google.com/project/invtracker-b19d1/crashlytics

**MCP Integration**: See [CRASHLYTICS_MCP_QUICKSTART.md](./CRASHLYTICS_MCP_QUICKSTART.md)

---

## Security Notes

- ✅ FIREBASE_TOKEN stored as GitHub Secret (encrypted)
- ✅ Token only has Crashlytics read permissions
- ✅ PRs created by `github-actions[bot]` (auditable)
- ✅ No sensitive crash data exposed in PR (links to Firebase Console)

---

**Workflow Status**: ✅ Active (runs every 6 hours)  
**Last Updated**: 2026-03-30  
**Maintainer**: InvTrack DevOps

