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

# Characters, not bytes: the listing uses ₹, emoji and box-drawing characters.
export LC_ALL=C.UTF-8

# One or more spaces, tabs, line breaks or no-break spaces, so a claim split
# across lines or joined with U+00A0 still matches.
S="([[:space:]]|"$'\xc2\xa0'")+"

# Claims that are false or unproven for this app. Data is stored in Cloud
# Firestore, and no security or accessibility audit exists. Matched
# case-insensitively, with straight or curly apostrophes.
BANNED_CLAIMS=(
  "do(es)?(n['’]?t|${S}not)${S}store"
  "never${S}(store|leave)"
  "stays${S}with${S}you"
  "(OWASP|MASVS)(${S}MASVS)?(${S}|-)compliant"
  "WCAG(${S}[0-9.]+)?(${S}A{1,3})?(${S}|-)compliant"
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

if [ "$(printf '₹' | wc -m)" -ne 1 ]; then
  echo "::error::Cannot count UTF-8 characters (C.UTF-8 locale missing)"
  exit 1
fi

if [ ! -d "$LISTING" ]; then
  echo "::error::Listing folder not found: $LISTING"
  exit 1
fi

# Grep follows a symlink named on the command line but skips the ones it
# meets while recursing, and the Play upload reads through them. Listing text
# must be real files so the checks below see what Play gets.
links=$(find "$LISTING" -type l)
if [ -n "$links" ]; then
  echo "$links"
  fail "Symlinks found above in the listing folder. Use regular files."
fi

# A deleted or renamed README must not turn the claims check off.
CLAIM_PATHS=("$LISTING")
if [ -f "$ROOT/README.md" ]; then
  CLAIM_PATHS+=("$ROOT/README.md")
else
  fail "README.md not found in $ROOT; it must be checked for banned claims."
fi

# scan MESSAGE GREP_ARGS...: prints each match (matches may span line
# breaks), and fails the check on a match or when grep cannot read a file.
scan() {
  local message=$1 rc
  shift
  grep -rHoziIE "$@" | tr '\0' '\n'
  rc=$?
  if [ "$rc" -eq 0 ]; then
    fail "$message"
  elif [ "$rc" -gt 1 ]; then
    fail "grep exited $rc; the listing could not be fully checked."
  fi
}

echo "Checking listing and README for banned claims..."
for pattern in "${BANNED_CLAIMS[@]}"; do
  scan "Banned claim /$pattern/ found above. Store and README text must match the Data safety form and privacy policy." \
    -- "$pattern" "${CLAIM_PATHS[@]}"
done

for pattern in "${LISTING_ONLY[@]}"; do
  scan "Version-specific header /$pattern/ found above. It goes stale; put release notes in changelogs/." \
    --include='*_description.txt' --include='title.txt' -- "$pattern" "$LISTING"
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
