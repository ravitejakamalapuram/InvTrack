#!/bin/bash
cd /Users/rkamalapuram/git-personal/InvTrack

git add -A

git commit -m "fix: Address CodeRabbit review comments from 2026-04-09

Fixed all actionable review comments from latest CodeRabbit review:

**Critical Fixes:**
- BulkWriter error handling: Track terminal failures and throw errors
- Functions: cleanupAnonymousUsers.ts now properly handles permanent write failures

**Major Fixes:**
- HealthScoreSnapshotModel: Include all score fields in equality/hashCode
- HealthScoreAutoSaveService: Fix forceSave() completion semantics with Completer
- ComponentScore: Add value equality (operator== and hashCode)
- CI: Fix flutter analyze flag (--fatal-warnings instead of --no-fatal-warnings)

**Minor Fixes:**
- Portfolio health: Include 90-day boundary in liquidity calculation
- Dashboard card: Replace hardcoded 'Portfolio Health' with localized string

**Trivial Fixes:**
- Localization: Add ARB entries for share text (shareScoreText, scoreCopiedToClipboard)
- Date formatting: Add locale parameter to DateFormat calls in trend chart
- Markdown: Add language identifiers to code blocks in MARATHON_SESSION_COMPLETE.md

All fixes maintain backward compatibility and pass flutter analyze.
Zero breaking changes."

git push origin HEAD

echo "Commit and push complete!"
