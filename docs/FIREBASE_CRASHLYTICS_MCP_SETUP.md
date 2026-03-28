# Firebase Crashlytics MCP Server Setup Guide

This guide helps you set up the Firebase Crashlytics MCP (Model Context Protocol) server to enable AI-assisted debugging and issue management for InvTrack.

## What is Firebase Crashlytics MCP?

Firebase Crashlytics MCP provides AI-powered tools to help you:
- **Prioritize and fix issues** through guided workflows
- **Debug conversationally** with your AI assistant
- **Retrieve crash context** including stack traces, user counts, and metadata
- **Manage issues** by adding notes, updating status, and closing issues

## Prerequisites

✅ **Already configured in InvTrack:**
- Firebase Crashlytics SDK integrated (`firebase_crashlytics: ^5.0.6`)
- Firebase project configured (`invtracker-b19d1`)
- Node.js and npm installed

⚠️ **Required setup:**
1. Install Firebase CLI
2. Authenticate with Firebase
3. Restart your AI coding assistant

## Installation Steps

### Step 1: Install Firebase CLI

Choose one method:

**Option A: Using npm (recommended)**
```bash
npm install -g firebase-tools
```

**Option B: Using standalone installer**
```bash
curl -sL https://firebase.tools | bash
```

**Verify installation:**
```bash
firebase --version
```

### Step 2: Authenticate with Firebase

Log in to your Firebase account:
```bash
firebase login
```

This will open a browser window. Sign in with the Google account that has access to the `invtracker-b19d1` project.

### Step 3: Verify Firebase Project

Confirm you can access the InvTrack Firebase project:
```bash
firebase projects:list
```

You should see `invtracker-b19d1` in the list.

### Step 4: Test MCP Server

Test that the MCP server works:
```bash
npx firebase-tools@latest mcp --generate-tool-list
```

This should display available Crashlytics MCP tools like:
- `crashlytics_get_issue`
- `crashlytics_list_events`
- `crashlytics_create_note`
- etc.

### Step 5: Restart Your AI Assistant

The MCP configuration has been created in `.vscode/mcp.json`. Restart your AI coding assistant (VS Code, Augment, etc.) to load the Firebase MCP server.

## MCP Configuration

The following configuration has been created in `.vscode/mcp.json`:

```json
{
  "servers": {
    "firebase": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "firebase-tools@latest", "mcp"]
    }
  }
}
```

## Usage Examples

### Guided Workflow (Recommended)

If your AI assistant supports MCP commands:
```
/crashlytics:connect
```

This launches a conversational workflow to:
1. View prioritized issues
2. Debug specific crashes
3. Get fix recommendations
4. Update issue status

### Conversational Debugging

Ask your AI assistant questions like:

**Retrieve crash context:**
> "What Crashlytics issues do I have related to login in the latest release?"

**Debug a specific issue:**
> "Debug issue abc123 - what's causing this crash?"

**Document investigation:**
> "Add a note to issue xyz789 summarizing this investigation and the proposed fix"

**Close resolved issues:**
> "Close issue abc123 and add a note with the PR link that fixed it"

## Available MCP Tools

The Firebase Crashlytics MCP server provides these tools:

### Manage Issues
- `crashlytics_create_note` - Add notes to issues
- `crashlytics_delete_note` - Remove notes from issues
- `crashlytics_update_issue` - Update issue status (open, closed, etc.)

### Retrieve Data
- `crashlytics_get_issue` - Get detailed issue information
- `crashlytics_list_events` - List crash events with filters
- `crashlytics_batch_get_events` - Get multiple events by ID
- `crashlytics_list_notes` - List all notes on an issue
- `crashlytics_get_report` - Get aggregated crash reports

## Troubleshooting

### Issue: "Firebase CLI not found"
**Solution:** Install Firebase CLI (see Step 1)

### Issue: "Not authenticated"
**Solution:** Run `firebase login` (see Step 2)

### Issue: "Project not found"
**Solution:** Ensure you're logged in with the correct Google account that has access to `invtracker-b19d1`

### Issue: "MCP tools not loading"
**Solution:** 
1. Verify Node.js is installed: `node --version`
2. Test MCP server manually: `npx firebase-tools@latest mcp --generate-tool-list`
3. Restart your AI assistant/IDE
4. Check `.vscode/mcp.json` exists and is valid JSON

### Issue: MCP not working with Unity projects
**Solution:** Use manual loading:
```bash
npx firebase-tools@latest mcp --only crashlytics
```

## Firebase Console Access

You can also view crashes directly in the Firebase Console:
- **Project:** invtracker-b19d1
- **Crashlytics Dashboard:** https://console.firebase.google.com/project/invtracker-b19d1/crashlytics

## Data Privacy

- Firebase does not charge for MCP tool usage or Crashlytics API access
- Data handling is determined by your AI assistant's terms
- MCP uses the same credentials as Firebase CLI (user account or application default)

## Resources

- **Official Guide:** https://firebase.google.com/docs/crashlytics/ai-assistance-mcp
- **Firebase CLI Docs:** https://firebase.google.com/docs/cli
- **MCP Protocol:** https://github.com/modelcontextprotocol

## Next Steps

After setup:
1. ✅ Restart your AI assistant
2. ✅ Test with a simple query: "List my recent Crashlytics issues"
3. ✅ Try the guided workflow: `/crashlytics:connect` (if supported)
4. ✅ Debug real issues from your production app

---

**Setup Date:** 2026-03-28  
**Firebase Project:** invtracker-b19d1  
**App:** InvTrack - Investment Tracker

