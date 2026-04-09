#!/bin/bash
cd /Users/rkamalapuram/git-personal/InvTrack

git add -A

git commit -m "fix: Fix analyzer errors from previous commit

Fixed 3 analyzer errors:
- health_score_auto_save_service.dart: Add null assertion to completer
- portfolio_health_dashboard_card.dart: Define l10n in _buildScoreCard
- Regenerated localization files with flutter gen-l10n

Result: 0 errors, 14 info warnings (cosmetic) ✅"

git push origin HEAD

echo "Commit and push complete!"
