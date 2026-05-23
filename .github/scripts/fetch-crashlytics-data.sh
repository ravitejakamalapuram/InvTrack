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

# Create Node.js script to fetch Crashlytics data using Firebase REST API
cat > fetch_crashes.js << 'SCRIPT_EOF'
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

const appId = process.env.FIREBASE_APP_ID;
const token = process.env.FIREBASE_TOKEN;
const reportType = process.env.REPORT_TYPE || 'topIssues';
const limit = parseInt(process.env.CRASH_LIMIT || '5');
const minUsers = parseInt(process.env.MIN_USERS || '5');
const projectId = process.env.FIREBASE_PROJECT_ID;

async function fetchCrashData() {
  try {
    console.error('Fetching Crashlytics data via Firebase CLI...');

    // Extract project number from app ID (format: 1:PROJECT_NUMBER:platform:APP_ID)
    const projectNumber = appId.split(':')[1];

    console.error(`Project Number: ${projectNumber}`);
    console.error(`App ID: ${appId}`);

    // Use the correct Crashlytics REST API endpoint
    // Endpoint: https://firebasecrashlytics.googleapis.com/v1alpha/projects/{projectNumber}/apps/{appId}/reports/{reportType}
    const apiUrl = `https://firebasecrashlytics.googleapis.com/v1alpha/projects/${projectNumber}/apps/${appId}/reports/${reportType}`;

    console.error(`API URL: ${apiUrl}`);

    // Try using Firebase token as OAuth token
    const curlCmd = `curl -s -H "Authorization: Bearer ${token}" "${apiUrl}?page_size=${limit}"`;

    let result;
    try {
      console.error('Attempting Crashlytics API call...');
      const { stdout, stderr } = await execPromise(curlCmd);

      if (stderr) {
        console.error('curl stderr:', stderr);
      }

      console.error('API Response:', stdout.substring(0, 200));

      result = JSON.parse(stdout);

      // Check if we got an error response
      if (result.error) {
        throw new Error(`API Error: ${result.error.message || JSON.stringify(result.error)}`);
      }

    } catch (apiError) {
      console.error('Crashlytics API call failed:', apiError.message);

      // Try getting fresh access token via Firebase CLI
      try {
        console.error('Trying to get fresh access token via Firebase CLI...');
        const { stdout: tokenOut } = await execPromise(
          `echo "${token}" | firebase login:add --no-localhost || echo "SKIP"`,
          { env: process.env }
        );

        // Get access token
        const { stdout: accessToken } = await execPromise(
          `firebase login:list --json | jq -r '.[0].tokens.access_token' || echo "${token}"`,
          { env: process.env }
        );

        const freshToken = accessToken.trim();
        console.error('Got fresh token, retrying API call...');

        const retryCurlCmd = `curl -s -H "Authorization: Bearer ${freshToken}" "${apiUrl}?page_size=${limit}"`;
        const { stdout } = await execPromise(retryCurlCmd);
        result = JSON.parse(stdout);

        if (result.error) {
          throw new Error(`API Error after token refresh: ${result.error.message}`);
        }

      } catch (tokenError) {
        console.error('Failed to refresh token and retry:', tokenError.message);

        // Final fallback: Exit with error (don't use test data in production)
        console.error('❌ Unable to fetch real Crashlytics data. API authentication failed.');
        console.error('Please verify:');
        console.error('1. FIREBASE_TOKEN is a valid CI token (run: firebase login:ci)');
        console.error('2. Token has Crashlytics API access permissions');
        console.error('3. Firebase project ID and app ID are correct');

        // Output empty result instead of test data
        console.log(JSON.stringify({
          crashes: [],
          total: 0,
          error: 'Failed to authenticate with Firebase Crashlytics API. Check token permissions.'
        }, null, 2));
        process.exit(0);
      }
    }

    // Parse Crashlytics API response
    // Response format: { rows: [ { dimensions: [values], metrics: [values] } ] }
    console.error(`Processing ${result.rows?.length || 0} crash reports...`);

    const rawCrashes = result.rows || [];

    // Filter crashes by minimum affected users
    // Metrics format: [deviceCount, eventCount, ...]
    const filteredCrashes = rawCrashes.filter(row => {
      const metrics = row.metrics || [];
      const deviceCount = parseInt(metrics[0] || 0); // First metric is impacted devices
      return deviceCount >= minUsers;
    });

    console.error(`Found ${filteredCrashes.length} crashes meeting criteria (min users: ${minUsers})`);

    // Format crashes for Jules with detailed context
    const crashes = filteredCrashes.slice(0, limit).map((row, index) => {
      const dimensions = row.dimensions || [];
      const metrics = row.metrics || [];

      // Dimensions format: [issueId, title, subtitle, ...]
      // Metrics format: [deviceCount, eventCount, ...]
      const issueId = dimensions[0] || `crash_${index}`;
      const displayName = dimensions[1] || 'Unknown crash';
      const subtitle = dimensions[2] || '';
      const deviceCount = parseInt(metrics[0] || 0);
      const eventCount = parseInt(metrics[1] || 0);

      return {
        id: issueId,
        title: displayName,
        eventCount: eventCount,
        affectedUsers: deviceCount,
        file: subtitle || 'Unknown file',
        stackTrace: `Crash in ${subtitle || 'unknown location'}`,
        priority: deviceCount > 50 ? 'high' : 'medium'
      };
    });

    // Output ONLY JSON to stdout
    console.log(JSON.stringify({ crashes, total: crashes.length }, null, 2));

  } catch (error) {
    console.error('Error fetching crash data:', error.message);
    console.error('Stack:', error.stack);

    // Fallback: Create empty crashes list (output to stdout)
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
