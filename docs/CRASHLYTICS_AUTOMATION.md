# Crashlytics Monitoring

**Automated AI-powered crash fixing with Jules AI + Manual monitoring via Firebase Console**

---

## Overview

InvTrack uses Firebase Crashlytics for crash reporting and monitoring with two approaches:

### 🤖 Automated Crash Fixing (Recommended)

**New:** Jules AI integration automatically detects, analyzes, and fixes crashes!

✅ **How it works:**
1. Daily GitHub Actions workflow fetches top crashes from Crashlytics
2. Jules AI (Google's coding agent) analyzes each crash
3. Generates comprehensive fixes with tests
4. Creates pull requests automatically
5. You review and merge the PRs

📖 **Full Guide:** See [JULES_CRASH_FIX_AUTOMATION.md](./JULES_CRASH_FIX_AUTOMATION.md)

**Benefits:**
- Proactive fixing without manual intervention
- AI-generated fixes following InvTrack standards
- Comprehensive test coverage
- Faster time from crash detection to deployment

### 📊 Manual Monitoring Options

For monitoring crashes directly:

1. **Firebase Console** (Real-time monitoring)
   - Visit [Firebase Crashlytics Console](https://console.firebase.google.com/project/invtracker-b19d1/crashlytics)
   - View real-time crash reports, stack traces, and affected users
   - Set up email alerts for critical crashes

2. **Firebase MCP Tools** (AI-assisted debugging)
   - Use Firebase CLI with MCP (Model Context Protocol)
   - Query crash data conversationally with AI
   - See `docs/FIREBASE_CRASHLYTICS_MCP_SETUP.md` for details

## Monitoring Crashes

### Firebase Console (Recommended)

1. **Navigate to Crashlytics**
   - Go to [Firebase Console](https://console.firebase.google.com/project/invtracker-b19d1/crashlytics)
   - Select your app: `InvTrack (Android)`

2. **View Crash Reports**
   - See crashes grouped by issue
   - View stack traces and device info
   - Check affected user count

3. **Set Up Email Alerts**
   - Go to Project Settings → Integrations
   - Enable Crashlytics alerts
   - Configure alert thresholds

### Firebase MCP Tools (Advanced)

For programmatic access to Crashlytics data:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Authenticate
firebase login

# Use MCP tools (see FIREBASE_CRASHLYTICS_MCP_SETUP.md for details)
npx firebase-tools mcp crashlytics:get-report --app-id=... --report=topIssues
```

---

## Crash Investigation Process

When crashes are detected:

1. **Prioritize by Impact**
   - Check affected user count
   - Review crash-free user percentage
   - Identify critical vs. minor issues

2. **Analyze Stack Traces**
   - Review the full stack trace
   - Identify the root cause
   - Check affected app versions

3. **Create Bug Fix**
   - Create GitHub issue or JIRA ticket
   - Link to Crashlytics issue
   - Implement fix and add regression tests

4. **Update Crashlytics**
   - Mark issue as resolved in Firebase Console
   - Add notes for future reference

---

## Related Documentation

| File | Purpose |
|------|---------|
| `docs/CRASHLYTICS_AUTOMATION.md` | This documentation |
| `docs/JULES_CRASH_FIX_AUTOMATION.md` | **NEW:** Jules AI automated crash fixing |
| `docs/FIREBASE_CRASHLYTICS_MCP_SETUP.md` | Firebase MCP tools setup |
| `docs/CRASHLYTICS_MCP_QUICKSTART.md` | Quick start guide for MCP tools |

---

## Example Crash Issue

When viewing crashes in Firebase Console, you'll see details like:

**Issue Title**: `NullPointerException in LoginScreen.dart:142`

**Details**:
- **Users affected**: 8 users
- **First seen**: 2026-05-17 08:30:00 UTC
- **App version**: 3.62.0
- **Device types**: Samsung Galaxy S21, Pixel 6, etc.

**Stack Trace**:
```
NullPointerException: Null check operator used on a null value
    at LoginScreen.build (LoginScreen.dart:142)
    at StatefulElement.build (element.dart:4893)
    ...
```

**Action Items**:
1. Review the stack trace
2. Identify the null value
3. Add null safety checks
4. Create regression test
5. Mark issue as resolved in Firebase Console

---

## Firebase Console Features

### Available Reports

- **Crash-free users**: Percentage of users not experiencing crashes
- **Crashes over time**: Trend graph showing crash frequency
- **Affected devices**: Device models and OS versions impacted
- **Breadcrumbs**: User actions leading up to crash
- **Custom keys**: Custom debug data logged via Crashlytics

### Email Alerts

Set up alerts to notify you when:
- New crash issues are detected
- Crash-free users drops below threshold
- Specific app versions have high crash rates

---

## Best Practices

1. **Monitor Daily**: Check Crashlytics dashboard daily for new issues
2. **Prioritize by Impact**: Focus on crashes affecting the most users
3. **Add Context**: Log custom keys and breadcrumbs for better debugging
4. **Track Versions**: Monitor crash rates across different app versions
5. **Test Fixes**: Add regression tests for all crash fixes
6. **Document Resolutions**: Add notes in Crashlytics when marking issues resolved

---

## 🚀 Quick Start with Jules AI

Want automated crash fixing? Follow these steps:

1. **Read the full guide:** [JULES_CRASH_FIX_AUTOMATION.md](./JULES_CRASH_FIX_AUTOMATION.md)
2. **Generate Jules API key:** https://jules.google.com/settings
3. **Connect your repository:** https://jules.google.com
4. **Configure GitHub secrets** (see guide for details)
5. **Trigger the workflow:** Actions tab → Jules AI Crash Fix Automation

That's it! Jules will automatically create PRs to fix crashes.

---

**Last Updated**: 2026-05-21
**Maintainer**: InvTrack DevOps

