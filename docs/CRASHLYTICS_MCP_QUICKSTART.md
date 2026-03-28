# Firebase Crashlytics MCP - Quick Start

**⚡ 5-Minute Setup for AI-Powered Crash Debugging**

## Quick Install

```bash
# 1. Install Firebase CLI (one-time)
npm install -g firebase-tools

# 2. Authenticate (one-time)
firebase login

# 3. Verify setup
npx firebase-tools@latest mcp --generate-tool-list

# 4. Restart your AI assistant (VS Code, Augment, etc.)
```

✅ **Configuration file already created:** `.vscode/mcp.json`

## Quick Usage

### Ask Your AI Assistant

**Get recent crashes:**
> "What are my recent Crashlytics issues?"

**Debug specific issue:**
> "Debug Crashlytics issue ABC123"

**Find login-related crashes:**
> "Show me crashes related to login in version 3.54.5"

**Add investigation notes:**
> "Add a note to issue XYZ789: 'Fixed by adding null check in auth flow'"

**Close resolved issue:**
> "Close Crashlytics issue ABC123 - fixed in PR #42"

### Guided Workflow (If Supported)

```
/crashlytics:connect
```

Then follow the conversational prompts to prioritize and fix issues.

## Available Commands (Your AI decides when to use these)

| Tool | Purpose |
|------|---------|
| `crashlytics_get_issue` | Get crash details, stack trace, user count |
| `crashlytics_list_events` | Find crash samples with filters |
| `crashlytics_create_note` | Document investigation findings |
| `crashlytics_update_issue` | Change issue status (open/closed) |
| `crashlytics_get_report` | Get aggregated crash statistics |

## Example Workflow

1. **User reports crash:**
   > "User says app crashes on login after update to 3.54.5"

2. **AI retrieves context:**
   - Lists recent crashes in version 3.54.5
   - Filters for login-related issues
   - Shows stack traces and error messages

3. **AI suggests fix:**
   - Analyzes code at crash location
   - Recommends null safety improvements
   - Provides code snippets

4. **You implement fix:**
   - Apply suggested changes
   - Test locally

5. **Document resolution:**
   > "Add note to issue ABC123: Fixed null pointer in LoginScreen.dart:142, deployed in v3.54.6"

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Not authenticated" | Run `firebase login` |
| "Tools not loading" | Restart AI assistant |
| "Permission denied" | Verify Firebase project access |

## Full Guide

📖 See [FIREBASE_CRASHLYTICS_MCP_SETUP.md](./FIREBASE_CRASHLYTICS_MCP_SETUP.md) for detailed setup and examples.

## Firebase Console

Alternative: View crashes at https://console.firebase.google.com/project/invtracker-b19d1/crashlytics

---

**Your Firebase Project:** invtracker-b19d1  
**Configuration:** `.vscode/mcp.json`

