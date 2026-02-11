#!/bin/bash
# Generate Play Store changelog from git commits
# Usage: ./scripts/generate-playstore-changelog.sh [version_code]

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get version code from pubspec.yaml if not provided
if [ -z "$1" ]; then
    VERSION_CODE=$(grep 'version:' pubspec.yaml | sed 's/.*+//')
    echo -e "${YELLOW}No version code provided, using from pubspec.yaml: ${VERSION_CODE}${NC}"
else
    VERSION_CODE=$1
fi

# Output file
OUTPUT_DIR="android/fastlane/metadata/android/en-US/changelogs"
OUTPUT_FILE="${OUTPUT_DIR}/${VERSION_CODE}.txt"

# Create directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}Generating Play Store changelog for version code ${VERSION_CODE}...${NC}"

# Generate changelog using git-cliff with Play Store config
git cliff --config cliff-playstore.toml --latest --strip all > "$OUTPUT_FILE"

# Check character count
CHAR_COUNT=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')

echo -e "${GREEN}✓ Changelog generated: ${OUTPUT_FILE}${NC}"
echo -e "${GREEN}✓ Character count: ${CHAR_COUNT}/500${NC}"

if [ "$CHAR_COUNT" -gt 500 ]; then
    echo -e "${RED}⚠️  WARNING: Changelog exceeds 500 character limit!${NC}"
    echo -e "${YELLOW}Please manually edit the file to reduce length.${NC}"
fi

# Show preview
echo -e "\n${YELLOW}Preview:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Offer to edit
echo -e "\n${YELLOW}Would you like to edit this changelog? (y/n)${NC}"
read -r EDIT_CHOICE

if [ "$EDIT_CHOICE" = "y" ] || [ "$EDIT_CHOICE" = "Y" ]; then
    ${EDITOR:-nano} "$OUTPUT_FILE"
    
    # Recheck character count after edit
    CHAR_COUNT=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
    echo -e "${GREEN}✓ Updated character count: ${CHAR_COUNT}/500${NC}"
    
    if [ "$CHAR_COUNT" -gt 500 ]; then
        echo -e "${RED}⚠️  Still exceeds 500 characters. Please reduce further.${NC}"
    fi
fi

echo -e "\n${GREEN}✓ Done! Changelog saved to: ${OUTPUT_FILE}${NC}"

