# Crashlytics MCP Access Guide

This guide shows how to access Crashlytics analytics using Firebase MCP tools in your AI development environment.

## Setup (Already Configured)

Your Firebase MCP server is already configured with:
- **Project ID**: `invtracker-b19d1`
- **Android App ID**: `1:784857267556:android:5ba7e064263d78f61dce71`
- **iOS App ID**: `1:784857267556:ios:c81b06c6f4a60a001dce71`

## Available Crashlytics MCP Tools

### 1. **Get Reports** (`crashlytics_get_report`)
Fetch aggregated analytics reports.

**Available Reports:**
- `topIssues` - Issues sorted by event count
- `topVersions` - Crashes grouped by app version
- `topOperatingSystems` - Crashes by OS version
- `topAndroidDevices` / `topAppleDevices` - Crashes by device type
- `topVariants` - Issue variants

**Example Prompt:**
```
"Show me the top 10 issues from the last 30 days for the Android app"
```

**What MCP does behind the scenes:**
```javascript
crashlytics_get_report({
  appId: "1:784857267556:android:5ba7e064263d78f61dce71",
  report: "topIssues",
  pageSize: 10,
  filter: {
    intervalStartTime: "2026-03-26T00:00:00Z",
    intervalEndTime: "2026-04-26T23:59:59Z"
  }
})
```

### 2. **Get Issue Details** (`crashlytics_get_issue`)
Fetch detailed information about a specific issue.

**Example Prompt:**
```
"Get details for issue 50a389e45315ab4cb1393f56b731f6ff"
```

**Returns:**
- Issue title and subtitle
- Error type (FATAL, NON_FATAL, ANR)
- First/last seen versions
- Signals (SIGNAL_REPETITIVE, SIGNAL_REGRESSED, SIGNAL_EARLY)
- Variants
- Sample event links

### 3. **List Crash Events** (`crashlytics_list_events`)
Fetch sample crash events with filters.

**Example Prompt:**
```
"Show me recent crash events for issue 50a389e45315ab4cb1393f56b731f6ff"
```

**Available Filters:**
- `issueId` - Filter by specific issue
- `issueErrorTypes` - FATAL, NON_FATAL, ANR
- `deviceFormFactors` - PHONE, TABLET, DESKTOP, TV, WATCH
- `versionDisplayNames` - Filter by app version
- `intervalStartTime` / `intervalEndTime` - Time range

### 4. **Manage Issues**

**Add Note** (`crashlytics_create_note`)
```
"Add a note to issue abc123 explaining the fix we're working on"
```

**Update Issue State** (`crashlytics_update_issue`)
```
"Close issue abc123 and add a note with the PR link"
```

**List Notes** (`crashlytics_list_notes`)
```
"Show me all notes for issue abc123"
```

## Recommended Workflows

### Workflow 1: Guided Debugging (Recommended)
Use the `crashlytics:connect` command for an interactive guided workflow:

```
/crashlytics:connect
```

This provides a conversational interface to:
- View prioritized issues
- Debug specific issues by ID or URL
- Request more context
- Get AI-suggested root causes
- Apply fixes

### Workflow 2: Free-form Conversation
Ask natural language questions:

**Examples:**
- "What are the top crashes in the latest release?"
- "A user reported login issues - are there related Crashlytics issues?"
- "Summarize issue 50a389e45315ab4cb1393f56b731f6ff and suggest a fix"
- "Show me ANR issues from the last week"
- "Which device models are most affected by crashes?"

## Current Top Issues (as of April 26, 2026)

1. **Issue ID**: `50a389e45315ab4cb1393f56b731f6ff`
   - **Type**: FATAL
   - **Events**: 435 (161 users affected)
   - **Error**: Firestore unavailable (transient connectivity issue)
   - **Signals**: REPETITIVE, REGRESSED (closed Mar 14, regressed Mar 21)

2. **Issue ID**: `330446834f8252710746c3a9fae30314`
   - **Type**: NON_FATAL
   - **Events**: 292 (96 users affected)
   - **Error**: GoogleSignIn canceled by user

3. **Issue ID**: `9dfdf1143e4d5e88cbfe9a9d91440e44`
   - **Type**: FATAL
   - **Events**: 184 (74 users affected)
   - **Error**: GoogleSignIn client configuration error (missing serverClientId)

## Usage Tips

1. **Always specify the app ID** when querying Crashlytics data
2. **Use date ranges** to focus on recent issues
3. **Filter by error type** to prioritize FATAL crashes
4. **Check signals** for issues marked REPETITIVE or REGRESSED
5. **Review notes** before debugging to avoid duplicate work

## Resources

- [Firebase Crashlytics MCP Documentation](https://firebase.google.com/docs/crashlytics/ai-assistance-mcp)
- [Firebase Console](https://console.firebase.google.com/project/invtracker-b19d1/crashlytics)
