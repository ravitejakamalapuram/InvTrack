#!/usr/bin/env bash
# Guards the Play listing (android/fastlane/metadata/android, pushed to Play by
# the `listing` workflow) and README.md against claims that contradict how the
# app handles data, and keeps the listing text within Play's length limits.
#
# Usage: scripts/check_store_listing.sh [repo_root]   (default: current dir)
# Exit status: 0 when clean, 1 when any check fails.
# Tests: test/scripts/check_store_listing_test.dart
set -uo pipefail

ROOT="${1:-.}"
LISTING="$ROOT/android/fastlane/metadata/android"
FAILED=0

fail() {
  echo "::error::$1"
  FAILED=1
}

# Claims that are false or unproven for this app. Data is stored in Cloud
# Firestore, and no security or accessibility audit exists. Matched
# case-insensitively, with straight or curly apostrophes.
BANNED_CLAIMS=(
  "do(n't|n’t|nt| not) store"
  "stays with you"
  "(OWASP|MASVS)( MASVS)? compliant"
  "WCAG( [0-9.]+)?( A{1,3})? compliant"
)

# Version-specific headers go stale in the listing (release notes belong in
# changelogs/, where a version number is fine).
LISTING_ONLY=("new in version [0-9]")

# Play limits, in characters.
declare -A MAX_CHARS=(
  [title.txt]=30
  [short_description.txt]=80
  [full_description.txt]=4000
)

# Characters, not bytes: the listing uses ₹, emoji and box-drawing characters.
export LC_ALL=C.UTF-8
if [ "$(printf '₹' | wc -m)" -ne 1 ]; then
  echo "::error::Cannot count UTF-8 characters (C.UTF-8 locale missing)"
  exit 1
fi

if [ ! -d "$LISTING" ]; then
  echo "::error::Listing folder not found: $LISTING"
  exit 1
fi

echo "Checking listing and README for banned claims..."
for pattern in "${BANNED_CLAIMS[@]}"; do
  if grep -rniIE "$pattern" "$LISTING" "$ROOT/README.md" 2>/dev/null; then
    fail "Banned claim /$pattern/ found above. Store and README text must match the Data safety form and privacy policy."
  fi
done

for pattern in "${LISTING_ONLY[@]}"; do
  if grep -rniIE --include='*_description.txt' --include='title.txt' \
    "$pattern" "$LISTING" 2>/dev/null; then
    fail "Version-specific header /$pattern/ found above. It goes stale; put release notes in changelogs/."
  fi
done

echo "Checking listing lengths..."
for locale_dir in "$LISTING"/*/; do
  for file in "${!MAX_CHARS[@]}"; do
    path="${locale_dir}${file}"
    if [ ! -f "$path" ]; then
      fail "Missing listing file: $path"
      continue
    fi
    # $(cat) drops trailing newlines, which Play does not count.
    chars=$(printf '%s' "$(cat "$path")" | wc -m)
    max=${MAX_CHARS[$file]}
    if [ "$chars" -gt "$max" ]; then
      fail "$path is $chars characters; Play allows $max."
    else
      echo "$path: $chars/$max"
    fi
  done
done

if [ "$FAILED" -ne 0 ]; then
  echo "Store listing check failed."
  exit 1
fi
echo "Store listing check passed."
