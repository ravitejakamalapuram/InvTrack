#!/bin/bash
set -e

# Fetch Crashlytics crash data using Firebase CLI
# This script retrieves top crashes from Firebase Crashlytics

echo "=================================================="
echo "Fetching Crashlytics Data"
echo "=================================================="
echo "Firebase Project: $FIREBASE_PROJECT_ID"
echo "Firebase App ID: $FIREBASE_APP_ID"
echo "Report Type: $REPORT_TYPE"
echo "Crash Limit: $CRASH_LIMIT"
echo "Min Affected Users: $MIN_USERS"
echo ""

# Validate required environment variables
if [ -z "$FIREBASE_TOKEN" ]; then
  echo "❌ Error: FIREBASE_TOKEN not set"
  echo "Generate token with: firebase login:ci"
  exit 1
fi

if [ -z "$FIREBASE_APP_ID" ]; then
  echo "❌ Error: FIREBASE_APP_ID not set"
  echo "Get your app ID from Firebase Console > Project Settings > General"
  exit 1
fi

# Create Node.js script to fetch Crashlytics data
cat > fetch_crashes.js << 'SCRIPT_EOF'
const https = require('https');

const appId = process.env.FIREBASE_APP_ID;
const token = process.env.FIREBASE_TOKEN;
const reportType = process.env.REPORT_TYPE || 'topIssues';
const limit = parseInt(process.env.CRASH_LIMIT || '5');
const minUsers = parseInt(process.env.MIN_USERS || '5');

// Note: This uses Firebase Crashlytics REST API
// Requires Firebase service account or OAuth token
// For now, we'll use a simpler approach with Firebase CLI MCP

const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

async function fetchCrashData() {
  try {
    console.log('Fetching Crashlytics data via Firebase CLI MCP...');
    
    // Use Firebase CLI MCP tools to get crash reports
    const cmd = `npx -y firebase-tools@latest mcp --json crashlytics_get_report --appId="${appId}" --report="${reportType}" --pageSize=${limit}`;
    
    const { stdout, stderr } = await execPromise(cmd, {
      env: { ...process.env, FIREBASE_TOKEN: token }
    });
    
    if (stderr) {
      console.error('Warning:', stderr);
    }
    
    const result = JSON.parse(stdout);
    
    // Filter crashes by minimum affected users
    const filteredCrashes = result.rows?.filter(row => {
      const userCount = parseInt(row.impactedDevicesCount || 0);
      return userCount >= minUsers;
    }) || [];
    
    console.log(`Found ${filteredCrashes.length} crashes meeting criteria`);
    
    // Format crashes for Jules
    const crashes = filteredCrashes.map((row, index) => ({
      id: row.issueId || `crash_${index}`,
      title: row.displayName || 'Unknown crash',
      eventCount: parseInt(row.eventCount || 0),
      affectedUsers: parseInt(row.impactedDevicesCount || 0),
      // We'll fetch detailed stack trace separately
      needsDetailedInfo: true
    }));
    
    console.log(JSON.stringify({ crashes, total: crashes.length }, null, 2));
    
  } catch (error) {
    console.error('Error fetching crash data:', error.message);
    
    // Fallback: Create empty crashes list
    console.log(JSON.stringify({ crashes: [], total: 0, error: error.message }, null, 2));
  }
}

fetchCrashData();
SCRIPT_EOF

# Execute Node.js script
echo "Executing crash data fetch..."
node fetch_crashes.js > crashlytics_data.json

# Parse and set outputs
CRASH_COUNT=$(jq -r '.total' crashlytics_data.json)
echo "crash_count=$CRASH_COUNT" >> $GITHUB_OUTPUT

if [ "$CRASH_COUNT" -eq 0 ]; then
  echo "✅ No crashes found meeting criteria (min users: $MIN_USERS)"
else
  echo "✅ Found $CRASH_COUNT crashes to process"
  echo ""
  echo "Top Crashes:"
  jq -r '.crashes[] | "  - \(.title) (\(.affectedUsers) users, \(.eventCount) events)"' crashlytics_data.json
fi

echo ""
echo "Crash data saved to: crashlytics_data.json"
