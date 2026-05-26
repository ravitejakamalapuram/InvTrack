#!/bin/bash
set -e

# Create Jules AI sessions for each crash
# Jules will analyze crashes, generate fixes, and create PRs automatically

echo "=================================================="
echo "Creating Jules AI Sessions for Crash Fixes"
echo "=================================================="
echo "Jules Source: $JULES_SOURCE_NAME"
echo "Crashes File: $CRASHES_FILE"
echo "Dry Run Mode: $DRY_RUN"
echo ""

# Validate required environment variables (in non-dry-run mode)
if [ "$DRY_RUN" != "true" ]; then
  if [ -z "$JULES_API_KEY" ]; then
    echo "❌ Error: JULES_API_KEY not set"
    echo "Generate API key from: https://jules.google.com/settings"
    exit 1
  fi

  if [ -z "$JULES_SOURCE_NAME" ]; then
    echo "❌ Error: JULES_SOURCE_NAME not set"
    echo "Format should be: sources/github-owner-repo"
    exit 1
  fi
fi

if [ ! -f "$CRASHES_FILE" ]; then
  echo "❌ Error: Crashes file not found: $CRASHES_FILE"
  exit 1
fi

# Check if there are any crashes
CRASH_COUNT=$(jq -r '.total' "$CRASHES_FILE")
if [ "$CRASH_COUNT" -eq 0 ]; then
  echo "ℹ️  No crashes to process"
  if [ -n "$GITHUB_OUTPUT" ]; then
    echo "session_count=0" >> $GITHUB_OUTPUT
  fi
  exit 0
fi

# Create Node.js script to create Jules sessions
cat > create_sessions.js << 'SCRIPT_EOF'
const https = require('https');
const fs = require('fs');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);
const { postCrashlyticsNote } = require('./.github/scripts/firebase-helper.js');

const apiKey = process.env.JULES_API_KEY;
const sourceName = process.env.JULES_SOURCE_NAME;
const crashesFile = process.env.CRASHES_FILE;
const appId = (process.env.FIREBASE_APP_ID || '').trim().replace(/['\"]/g, '');
const dryRun = process.env.DRY_RUN === 'true';

// Read crashes data
const crashData = JSON.parse(fs.readFileSync(crashesFile, 'utf8'));
const crashes = crashData.crashes || [];

console.log(`Processing ${crashes.length} crashes...`);

const sessions = [];

async function getOpenPRs() {
  try {
    console.log('Retrieving open Pull Requests from GitHub to check for duplicate fixes...');
    const { stdout } = await execPromise('gh pr list --state open --json title,body,headRefName');
    return JSON.parse(stdout);
  } catch (err) {
    console.error('Error: Failed to fetch open Pull Requests via GitHub CLI (check GH_TOKEN permissions):', err.message);
    throw err;
  }
}

async function createJulesSession(crash) {
  return new Promise((resolve, reject) => {
    const prompt = `Fix critical crash in InvTrack Flutter app

**Crash Details:**
- **Title:** ${crash.title}
- **Subtitle:** ${crash.subtitle || ''}
- **Crash ID:** ${crash.id}
- **Occurrences:** ${crash.eventCount} events
- **Impacted Users:** ${crash.affectedUsers} users
- **App Version:** ${crash.appVersion || 'Unknown'}
- **OS Version:** ${crash.osVersion || 'Unknown'}
- **Device Model:** ${crash.deviceModel || 'Unknown'}
${crash.blameFrame ? `- **Blamed Location:** ${crash.blameFrame.symbol || ''} (in ${crash.blameFrame.file || ''}:${crash.blameFrame.line || ''})` : ''}

**Stack Trace:**
\`\`\`
${crash.stackTrace}
\`\`\`

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

    if (dryRun) {
      console.log(`\n🧪 [DRY RUN] Would create session for: ${crash.title}`);
      console.log(`🧪 [DRY RUN] Prompt preview:`);
      console.log(prompt.substring(0, 300) + '...\n');
      
      const mockSession = {
        id: `mock_session_${crash.id}`,
        url: `https://jules.google.com/sessions/mock_${crash.id}`
      };
      
      return resolve({ crash, session: mockSession });
    }

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
  const openPRs = await getOpenPRs();
  
  for (const crash of crashes) {
    // smart deduplication
    const hasDuplicatePR = openPRs.some(pr => {
      const inTitle = pr.title && pr.title.includes(crash.id);
      const inBody = pr.body && pr.body.includes(crash.id);
      const inBranch = pr.headRefName && pr.headRefName.includes(crash.id);
      return inTitle || inBody || inBranch;
    });
    
    if (hasDuplicatePR) {
      console.log(`\n⏭️  Skipping crash: ${crash.title} (Crash ID: ${crash.id})`);
      console.log(`   Reason: An open Pull Request already references this Crash ID.`);
      continue;
    }
    
    try {
      const result = await createJulesSession(crash);
      sessions.push(result);
      
      // Post Note to Firebase Crashlytics Issue Console (non-dry-run only)
      if (!dryRun && appId && result.session.url) {
        const noteText = `🤖 Jules AI has started an automated crash-fix session for this issue.\nJules Session: ${result.session.url}`;
        await postCrashlyticsNote(appId, crash.id, noteText);
      }
      
      // Rate limiting: wait 2 seconds between requests
      await new Promise(resolve => setTimeout(resolve, 2000));
    } catch (error) {
      console.error(`Failed to create session for crash ${crash.id}:`, error.message);
      process.exit(1);
    }
  }
  
  // Save sessions data
  fs.writeFileSync('jules_sessions.json', JSON.stringify({ sessions }, null, 2));
  console.log(`\n✅ Processed ${sessions.length} Jules sessions`);
  console.log(`Sessions saved to: jules_sessions.json`);
}

createAllSessions().catch(err => {
  console.error(err);
  process.exit(1);
});
SCRIPT_EOF

# Execute Node.js script
echo "Creating Jules sessions..."
node create_sessions.js

# Set output
SESSION_COUNT=$(jq -r '.sessions | length' jules_sessions.json 2>/dev/null || echo "0")

if [ -n "$GITHUB_OUTPUT" ]; then
  echo "session_count=$SESSION_COUNT" >> $GITHUB_OUTPUT
fi

echo ""
echo "✅ Finished processing $SESSION_COUNT Jules AI sessions"
