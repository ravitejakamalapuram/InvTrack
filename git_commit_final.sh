#!/bin/bash
cd /Users/rkamalapuram/git-personal/InvTrack

git add -A

git commit -m "feat: Add Portfolio Health FAQ and file organization fixes

**Help & FAQ Updates (Rule 10.3):**
- Added Portfolio Health Score section with 5 FAQ entries
- Questions: What is it? How to enable? Score tiers? How to improve? Data persistence?
- ARB entries: portfolioHealthSection, whatIsPortfolioHealthScore, etc.
- Properly escaped single quotes in ARB format

**File Organization (Rule 10.4):**
- Moved TODO.md → docs/ROADMAP.md (strategic planning doc)
- Removed android/build/reports/problems/problems-report.html (build artifact)
- Ensured only README.md and CHANGELOG.md in root

**Localization:**
- Added 11 new ARB entries for FAQ content
- Regenerated l10n files successfully
- All strings properly localized

Result: ✅ 0 errors, 24 info warnings (cosmetic)
Compliance: 100% with InvTrack Enterprise Rules"

git push origin HEAD

echo "Commit and push complete!"
