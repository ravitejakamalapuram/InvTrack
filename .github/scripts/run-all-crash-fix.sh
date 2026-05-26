#!/bin/bash
# Fail fast: exit immediately if any command exits with a non-zero status
set -e

echo "=================================================="
echo "🤖 Starting Jules AI Crash Fix Orchestrator"
echo "=================================================="

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env..."
  # Export variables from .env, ignoring comments and empty lines
  export $(grep -v '^#' .env | xargs)
fi

# Set default values for configurable variables
export FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-"invtracker-b19d1"}
export REPORT_TYPE=${REPORT_TYPE:-"topIssues"}
export CRASH_LIMIT=${CRASH_LIMIT:-"5"}
export MIN_USERS=${MIN_USERS:-"1"}
export ISSUE_ERROR_TYPES=${ISSUE_ERROR_TYPES:-"FATAL,NON_FATAL,ANR"}
export DRY_RUN=${DRY_RUN:-"false"}
export MAX_WAIT_MINUTES=${MAX_WAIT_MINUTES:-"60"}
export CRASHES_FILE=${CRASHES_FILE:-"crashlytics_data.json"}

# Set up credentials if FIREBASE_CREDENTIALS is a JSON string
if [ -n "$FIREBASE_CREDENTIALS" ] && [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  echo "Setting up Google Application Credentials from FIREBASE_CREDENTIALS..."
  echo "$FIREBASE_CREDENTIALS" > /tmp/firebase-service-account.json
  export GOOGLE_APPLICATION_CREDENTIALS=/tmp/firebase-service-account.json
fi

# Ensure google-auth-library is installed locally
if ! node -e "require('google-auth-library')" >/dev/null 2>&1; then
  echo "Installing google-auth-library..."
  npm install google-auth-library
fi

# Define a cleanup function to remove temporary node files
cleanup() {
  echo "🧹 Cleaning up temporary Node files..."
  rm -f fetch_crashes.js create_sessions.js monitor_sessions.js
}
trap cleanup EXIT

# 1. Fetch Crashlytics Data
echo "🚀 [Step 1/4] Fetching crash data from Firebase Crashlytics..."
bash .github/scripts/fetch-crashlytics-data.sh

# Get crash count
if [ -f "$CRASHES_FILE" ]; then
  CRASH_COUNT=$(jq -r '.total // 0' "$CRASHES_FILE" 2>/dev/null || echo "0")
else
  CRASH_COUNT=0
fi

if [ "$CRASH_COUNT" -eq 0 ]; then
  echo "ℹ️ No crashes found matching the criteria. Exiting successfully."
  exit 0
fi

# 2. Create Jules AI Sessions
echo "🚀 [Step 2/4] Creating Jules AI developer sessions..."
bash .github/scripts/create-jules-sessions.sh

# Get session count
if [ -f "jules_sessions.json" ]; then
  SESSION_COUNT=$(jq -r '.sessions | length' jules_sessions.json 2>/dev/null || echo "0")
else
  SESSION_COUNT=0
fi

if [ "$SESSION_COUNT" -eq 0 ]; then
  echo "ℹ️ No Jules sessions were successfully created. Exiting."
  exit 0
fi

# 3. Monitor Jules AI Sessions
echo "🚀 [Step 3/4] Monitoring Jules AI sessions..."
bash .github/scripts/monitor-jules-sessions.sh

# 4. Create Summary Issue
echo "🚀 [Step 4/4] Creating session execution summary..."
bash .github/scripts/create-summary-issue.sh

echo "🎉 Jules AI Crash Fix pipeline run completed successfully!"
