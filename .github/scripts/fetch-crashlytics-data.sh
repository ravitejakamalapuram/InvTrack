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
echo "Error Types: $ISSUE_ERROR_TYPES"
echo ""

if [ -z "$FIREBASE_APP_ID" ]; then
  echo "❌ Error: FIREBASE_APP_ID not set"
  echo "Get your app ID from Firebase Console > Project Settings > General"
  exit 1
fi

# Create Node.js script to fetch Crashlytics data using Firebase REST API
cat > fetch_crashes.js << 'SCRIPT_EOF'
const fs = require('fs');
const { getAccessToken, httpRequest } = require('./.github/scripts/firebase-helper.js');

const appId = process.env.FIREBASE_APP_ID;
const reportType = process.env.REPORT_TYPE || 'topIssues';
const limit = parseInt(process.env.CRASH_LIMIT || '5');
const minUsers = parseInt(process.env.MIN_USERS || '5');

async function fetchCrashData() {
  try {
    console.error('Starting Crashlytics data fetch process...');

    // Extract project number from app ID (format: 1:PROJECT_NUMBER:platform:APP_ID)
    const projectNumber = appId.split(':')[1];

    console.error(`Project Number: ${projectNumber}`);
    console.error(`App ID: ${appId}`);

    // Get OAuth2 access token
    const accessToken = await getAccessToken();

    // Parse error types filter
    const errorTypes = (process.env.ISSUE_ERROR_TYPES || 'FATAL')
      .split(',')
      .map(s => s.trim().toUpperCase())
      .filter(s => s === 'FATAL' || s === 'NON_FATAL' || s === 'ANR');

    const params = new URLSearchParams();
    params.set('page_size', `${limit}`);
    for (const errorType of errorTypes) {
      params.append('filter.issue.error_types', errorType);
    }

    // Call Crashlytics Reports REST API
    const apiUrl = `https://firebasecrashlytics.googleapis.com/v1alpha/projects/${projectNumber}/apps/${appId}/reports/${reportType}?${params.toString()}`;
    console.error(`Calling Crashlytics API: ${apiUrl}`);

    const result = await httpRequest(apiUrl, 'GET', null, accessToken);
    
    console.error(`Processing ${result.groups?.length || 0} crash groups...`);

    const rawGroups = result.groups || [];

    // Filter crashes by minimum affected users
    const filteredGroups = rawGroups.filter(group => {
      const metrics = group.metrics?.[0] || {};
      const deviceCount = parseInt(metrics.impactedUsersCount || 0);
      return deviceCount >= minUsers;
    });

    console.error(`Found ${filteredGroups.length} crashes meeting criteria (min users: ${minUsers})`);

    // Format crashes for Jules with detailed context
    const crashes = [];
    
    for (const group of filteredGroups.slice(0, limit)) {
      const issue = group.issue || {};
      const metrics = group.metrics?.[0] || {};
      const issueId = issue.id || `unknown_${Date.now()}`;
      const title = issue.title || 'Unknown crash';
      const subtitle = issue.subtitle || '';
      const deviceCount = parseInt(metrics.impactedUsersCount || 0);
      const eventCount = parseInt(metrics.eventsCount || 0);

      // Default values
      let stackTrace = `Crash in ${subtitle || title || 'unknown location'}`;
      let appVersion = issue.firstSeenVersion || 'unknown';
      let osVersion = 'unknown';
      let deviceModel = 'unknown';
      let blameFrame = null;

      // Fetch sample event details to get the actual stack trace and metadata
      if (issue.sampleEvent) {
        try {
          console.error(`Fetching sample event details for issue ${issueId}...`);
          const eventUrl = `https://firebasecrashlytics.googleapis.com/v1alpha/projects/${projectNumber}/apps/${appId}/events:batchGet?names=${encodeURIComponent(issue.sampleEvent)}`;
          const eventResponse = await httpRequest(eventUrl, 'GET', null, accessToken);
          const event = eventResponse.events?.[0];
          
          if (event) {
            // Extract stack trace from event
            let formattedTrace = '';
            
            // 1. Check exceptions
            if (event.exceptions && event.exceptions.length > 0) {
              formattedTrace = event.exceptions.map(exception => {
                const header = exception.nested ? "Caused by: " : "";
                const exceptionHeader = `${header}${exception.type || ""}: ${exception.exceptionMessage || exception.subtitle || ""}`;
                const framesStr = (exception.frames || []).map(f => {
                  let line = `  at`;
                  if (f.symbol) line += ` ${f.symbol}`;
                  if (f.file) {
                    line += ` (${f.file}`;
                    if (f.line) line += `:${f.line}`;
                    line += `)`;
                  }
                  return line;
                }).join('\n');
                return `${exceptionHeader}\n${framesStr}`;
              }).join('\n\n');
            } 
            // 2. Check crashed/blamed threads
            else if (event.threads && event.threads.length > 0) {
              const crashedThread = event.threads.find(t => t.crashed || t.blamed) || event.threads[0];
              if (crashedThread) {
                const header = `Thread: ${crashedThread.name || crashedThread.threadId || ""}${crashedThread.crashed ? " (crashed)" : ""}`;
                const framesStr = (crashedThread.frames || []).map(f => {
                  let line = `  at`;
                  if (f.symbol) line += ` ${f.symbol}`;
                  if (f.file) {
                    line += ` (${f.file}`;
                    if (f.line) line += `:${f.line}`;
                    line += `)`;
                  }
                  return line;
                }).join('\n');
                formattedTrace = `${header}\n${framesStr}`;
              }
            }

            if (formattedTrace) {
              stackTrace = formattedTrace;
            }

            // Extract metadata
            if (event.version) {
              appVersion = event.version.displayName || event.version.displayVersion || appVersion;
            }
            if (event.operatingSystem) {
              osVersion = event.operatingSystem.displayName || event.operatingSystem.displayVersion || osVersion;
            }
            if (event.device) {
              deviceModel = `${event.device.manufacturer || ''} ${event.device.model || ''} (${event.device.formFactor || ''})`.trim() || deviceModel;
            }
            if (event.blameFrame) {
              blameFrame = event.blameFrame;
            }
          }
        } catch (eventError) {
          console.error(`Failed to fetch event details for sample ${issue.sampleEvent}:`, eventError.message);
        }
      }

      crashes.push({
        id: issueId,
        title: title,
        subtitle: subtitle,
        eventCount: eventCount,
        affectedUsers: deviceCount,
        appVersion: appVersion,
        osVersion: osVersion,
        deviceModel: deviceModel,
        blameFrame: blameFrame,
        stackTrace: stackTrace,
        priority: deviceCount > 50 ? 'high' : 'medium'
      });
    }

    // Output ONLY JSON to stdout
    console.log(JSON.stringify({ crashes, total: crashes.length }, null, 2));

  } catch (error) {
    console.error('Error fetching crash data:', error.message);
    console.error('Stack:', error.stack);

    // Fallback: Output empty result
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

# Check if $GITHUB_OUTPUT is set before writing to it (for local testing)
if [ -n "$GITHUB_OUTPUT" ]; then
  echo "crash_count=$CRASH_COUNT" >> $GITHUB_OUTPUT
fi

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
