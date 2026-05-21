#!/bin/bash
set -e

# Create Jules AI sessions for each crash
# Jules will analyze crashes, generate fixes, and create PRs automatically

echo "=================================================="
echo "Creating Jules AI Sessions for Crash Fixes"
echo "=================================================="
echo "Jules Source: $JULES_SOURCE_NAME"
echo "Crashes File: $CRASHES_FILE"
echo ""

# Validate required environment variables
if [ -z "$JULES_API_KEY" ]; then
  echo "❌ Error: JULES_API_KEY not set"
  echo "Generate API key from: https://jules.google.com/settings"
  exit 1
fi

if [ -z "$JULES_SOURCE_NAME" ]; then
  echo "❌ Error: JULES_SOURCE_NAME not set"
  echo "Get source name with: curl -H 'x-goog-api-key: \$JULES_API_KEY' https://jules.googleapis.com/v1alpha/sources"
  echo "Format should be: sources/github-owner-repo"
  exit 1
fi

if [ ! -f "$CRASHES_FILE" ]; then
  echo "❌ Error: Crashes file not found: $CRASHES_FILE"
  exit 1
fi

# Check if there are any crashes
CRASH_COUNT=$(jq -r '.total' "$CRASHES_FILE")
if [ "$CRASH_COUNT" -eq 0 ]; then
  echo "ℹ️  No crashes to process"
  echo "session_count=0" >> $GITHUB_OUTPUT
  exit 0
fi

# Create Node.js script to create Jules sessions
cat > create_sessions.js << 'SCRIPT_EOF'
const https = require('https');
const fs = require('fs');

const apiKey = process.env.JULES_API_KEY;
const sourceName = process.env.JULES_SOURCE_NAME;
const crashesFile = process.env.CRASHES_FILE;

// Read crashes data
const crashData = JSON.parse(fs.readFileSync(crashesFile, 'utf8'));
const crashes = crashData.crashes || [];

console.log(`Processing ${crashes.length} crashes...`);

const sessions = [];

async function createJulesSession(crash) {
  return new Promise((resolve, reject) => {
    const prompt = `Fix critical crash in InvTrack Flutter app

**Crash Details:**
- Title: ${crash.title}
- Event Count: ${crash.eventCount} occurrences
- Affected Users: ${crash.affectedUsers} users
- Crash ID: ${crash.id}

**Task Requirements:**
1. **Analyze Root Cause:**
   - Review the crash location and stack trace
   - Identify the underlying issue (null safety, async errors, state management, etc.)
   - Explain the root cause clearly

2. **Implement Defensive Fix:**
   - Add proper null checks and validation
   - Handle edge cases that caused the crash
   - Use Flutter/Dart best practices:
     * Null safety (!= operator usage)
     * Proper async/await error handling
     * Riverpod state management patterns (if applicable)
     * Widget lifecycle considerations

3. **Add Comprehensive Tests:**
   - Unit tests for business logic fixes
   - Widget tests for UI-related crashes
   - Test edge cases that triggered the crash
   - Ensure tests prevent regression

4. **Follow InvTrack Standards:**
   - Match existing code style and architecture
   - Use Riverpod for state management
   - Follow localization patterns (use AppLocalizations)
   - Add proper error logging with Firebase Crashlytics context

5. **Documentation:**
   - Add inline comments explaining the fix
   - Update relevant documentation if needed
   - Reference this crash in commit message: ${crash.id}

**Expected Deliverables:**
- Fixed code with defensive programming
- Comprehensive test coverage
- Clear commit message linking to Crashlytics issue
- No new analyzer warnings or errors`;

    const requestData = JSON.stringify({
      prompt: prompt,
      title: `Fix: ${crash.title.substring(0, 60)}...`,
      sourceContext: {
        source: sourceName,
        githubRepoContext: {
          startingBranch: 'main'
        }
      },
      automationMode: 'AUTO_CREATE_PR',
      requirePlanApproval: false  // Auto-approve plans for automated workflow
    });

    const options = {
      hostname: 'jules.googleapis.com',
      path: '/v1alpha/sessions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(requestData),
        'x-goog-api-key': apiKey
      }
    };

    console.log(`\nCreating session for: ${crash.title}`);
    
    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 200) {
          const session = JSON.parse(data);
          console.log(`✅ Session created: ${session.id}`);
          console.log(`   URL: ${session.url}`);
          resolve({ crash, session });
        } else {
          console.error(`❌ Failed to create session: HTTP ${res.statusCode}`);
          console.error(data);
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', (error) => {
      console.error(`❌ Request failed:`, error.message);
      reject(error);
    });

    req.write(requestData);
    req.end();
  });
}

async function createAllSessions() {
  for (const crash of crashes) {
    try {
      const result = await createJulesSession(crash);
      sessions.push(result);
      
      // Rate limiting: wait 2 seconds between requests
      await new Promise(resolve => setTimeout(resolve, 2000));
    } catch (error) {
      console.error(`Failed to create session for crash ${crash.id}:`, error.message);
    }
  }
  
  // Save sessions data
  fs.writeFileSync('jules_sessions.json', JSON.stringify({ sessions }, null, 2));
  console.log(`\n✅ Created ${sessions.length} Jules sessions`);
  console.log(`Sessions saved to: jules_sessions.json`);
}

createAllSessions().catch(console.error);
SCRIPT_EOF

# Execute Node.js script
echo "Creating Jules sessions..."
node create_sessions.js

# Set output
SESSION_COUNT=$(jq -r '.sessions | length' jules_sessions.json 2>/dev/null || echo "0")
echo "session_count=$SESSION_COUNT" >> $GITHUB_OUTPUT

echo ""
echo "✅ Created $SESSION_COUNT Jules AI sessions"
