#!/bin/bash
set -e

# Create GitHub issue summarizing Jules crash fix sessions
# Posts a detailed summary of all sessions and PRs created

echo "=================================================="
echo "Creating Summary GitHub Issue"
echo "=================================================="

# Check if we have results to summarize
if [ ! -f "session_results.json" ]; then
  echo "⚠️  Warning: session_results.json not found"

  # Check if we have session data to create a minimal summary
  if [ ! -f "jules_sessions.json" ]; then
    echo "ℹ️  No session data found - skipping summary"
    exit 0
  fi

  echo "ℹ️  Creating summary from session data only..."

  # Create a minimal results file indicating sessions were created but not monitored
  cat > session_results.json << 'EOF'
{
  "results": [],
  "note": "Sessions were created but monitoring data is unavailable"
}
EOF
fi

RESULT_COUNT=$(jq -r '.results | length' session_results.json)
SESSION_COUNT=$(jq -r '.sessions | length' jules_sessions.json 2>/dev/null || echo "0")

if [ "$RESULT_COUNT" -eq 0 ] && [ "$SESSION_COUNT" -eq 0 ]; then
  echo "ℹ️  No results to summarize"
  exit 0
fi

# Generate summary markdown
cat > session_summary.md << 'SUMMARY_EOF'
# 🤖 Jules AI Crash Fix Automation - Session Summary

**Workflow Run:** #{WORKFLOW_RUN}
**Date:** {RUN_DATE}
**Triggered By:** {TRIGGERED_BY}

---

## 📊 Overview

SUMMARY_EOF

# Insert statistics
node << 'STATS_EOF'
const fs = require('fs');
const results = JSON.parse(fs.readFileSync('session_results.json', 'utf8')).results || [];
const sessions = JSON.parse(fs.readFileSync('jules_sessions.json', 'utf8')).sessions || [];

const completed = results.filter(r => r.status === 'COMPLETED');
const completedNoPr = results.filter(r => r.status === 'COMPLETED_NO_PR');
const failed = results.filter(r => r.status === 'FAILED');
const timeout = results.filter(r => r.status === 'TIMEOUT');
const awaitingFeedback = results.filter(r => r.status === 'AWAITING_USER_FEEDBACK');

const totalAnalyzed = results.length > 0 ? results.length : sessions.length;

const summary = `
- **Total Crashes Analyzed:** ${totalAnalyzed}
- **✅ PRs Created:** ${completed.length}
- **✓ Completed (No PR):** ${completedNoPr.length}
- **❌ Failed:** ${failed.length}
- **⏱️ Timed Out:** ${timeout.length}
- **👤 Awaiting User Feedback:** ${awaitingFeedback.length}

---

## 🔧 Pull Requests Created

${completed.length > 0 ? completed.map(r => `
### ${r.crash.title}

- **PR:** ${r.prUrl}
- **Crash ID:** \`${r.crash.id}\`
- **Affected Users:** ${r.crash.affectedUsers}
- **Event Count:** ${r.crash.eventCount}
- **Processing Time:** ${r.elapsed}s
- **Jules Session:** ${r.url}

**Next Steps:**
1. Review the PR code changes
2. Run tests locally if needed
3. Approve and merge when ready
`).join('\n---\n') : '_No PRs were created in this run._'}

---

## 📝 Completed Sessions (No PR)

${completedNoPr.length > 0 ? completedNoPr.map(r => `
- **${r.crash.title}**
  - Status: Completed without creating a PR
  - Session: ${r.url}
  - Possible Reason: Fix not needed, or manual intervention required
`).join('\n') : '_None_'}

---

## ❌ Failed Sessions

${failed.length > 0 ? failed.map(r => `
- **${r.crash.title}**
  - Status: Failed
  - Session: ${r.url}
  - Action: Review session logs for error details
`).join('\n') : '_None_'}

---

## ⏱️ Timed Out Sessions

${timeout.length > 0 ? timeout.map(r => `
- **${r.crash.title}**
  - Status: Timed out after ${r.elapsed}s
  - Session: ${r.url}
  - Note: Session may still complete - check Jules dashboard
`).join('\n') : '_None_'}

---

## 👤 Awaiting User Feedback

${awaitingFeedback.length > 0 ? awaitingFeedback.map(r => `
- **${r.crash.title}**
  - Status: Awaiting user feedback
  - Session: ${r.url}
  - Action Required: Review and approve/reject in Jules dashboard
  - Note: ${r.note || 'Manual approval needed'}
`).join('\n') : '_None_'}

---

## 📚 Resources

- **Jules Dashboard:** https://jules.google.com
- **Firebase Crashlytics:** https://console.firebase.google.com/project/invtracker-b19d1/crashlytics
- **Documentation:** [Jules Crash Fix Automation](../docs/JULES_CRASH_FIX_AUTOMATION.md)

---

## 🔄 Next Run

This workflow runs daily at 9 AM UTC or can be triggered manually from the Actions tab.

To adjust settings, edit \`.github/workflows/jules-crash-fix.yml\`

---

_Automated by Jules AI Crash Fix workflow_
`;

fs.appendFileSync('session_summary.md', summary);
STATS_EOF

# Replace placeholders
sed -i.bak "s/{WORKFLOW_RUN}/$GITHUB_RUN_NUMBER/g" session_summary.md
sed -i.bak "s/{RUN_DATE}/$(date -u +"%Y-%m-%d %H:%M:%S UTC")/g" session_summary.md
sed -i.bak "s/{TRIGGERED_BY}/$GITHUB_ACTOR/g" session_summary.md

# Create GitHub issue
ISSUE_TITLE="🤖 Jules AI Crash Fix - Run #$GITHUB_RUN_NUMBER"
ISSUE_BODY=$(cat session_summary.md)

echo "Creating GitHub issue..."
gh issue create \
  --title "$ISSUE_TITLE" \
  --body "$ISSUE_BODY"

echo "✅ Summary issue created"
