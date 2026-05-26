#!/bin/bash
set -e

# Monitor Jules AI sessions until completion or timeout
# Polls session status and reports on PR creation

echo "=================================================="
echo "Monitoring Jules AI Sessions"
echo "=================================================="
echo "Max Wait Time: $MAX_WAIT_MINUTES minutes"
echo ""

# Validate required environment variables
if [ -z "$JULES_API_KEY" ]; then
  echo "❌ Error: JULES_API_KEY not set"
  exit 1
fi

if [ ! -f "jules_sessions.json" ]; then
  echo "ℹ️  No sessions to monitor"
  exit 0
fi

SESSION_COUNT=$(jq -r '.sessions | length' jules_sessions.json)
if [ "$SESSION_COUNT" -eq 0 ]; then
  echo "ℹ️  No sessions to monitor"
  exit 0
fi

# Create Node.js script to monitor sessions
cat > monitor_sessions.js << 'SCRIPT_EOF'
const https = require('https');
const fs = require('fs');
const { postCrashlyticsNote } = require('./.github/scripts/firebase-helper.js');

const apiKey = process.env.JULES_API_KEY;
const maxWaitMinutes = parseInt(process.env.MAX_WAIT_MINUTES || '30');
const appId = (process.env.FIREBASE_APP_ID || '').trim().replace(/['\"]/g, '');
const checkIntervalSeconds = 60;

// Read sessions data
const sessionsData = JSON.parse(fs.readFileSync('jules_sessions.json', 'utf8'));
const sessions = sessionsData.sessions || [];

console.log(`Monitoring ${sessions.length} sessions...`);

const results = [];

async function getSessionStatus(sessionId) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'jules.googleapis.com',
      path: `/v1alpha/sessions/${sessionId}`,
      method: 'GET',
      headers: {
        'x-goog-api-key': apiKey
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

async function monitorSession(sessionInfo) {
  const { crash, session } = sessionInfo;
  const sessionId = session.id;
  const startTime = Date.now();
  const maxWaitMs = maxWaitMinutes * 60 * 1000;
  const isMock = sessionId.startsWith('mock_session_');
  
  console.log(`\n📊 Monitoring: ${crash.title}`);
  console.log(`   Session: ${sessionId}`);
  
  if (isMock) {
    console.log(`   State: COMPLETED (Mocked)`);
    console.log(`✅ [MOCK] PR Created: https://github.com/ravitejakamalapuram/InvTrack/pull/mock_${crash.id}`);
    return {
      crash,
      sessionId,
      status: 'COMPLETED',
      prUrl: `https://github.com/ravitejakamalapuram/InvTrack/pull/mock_${crash.id}`,
      prTitle: `Fix: ${crash.title.substring(0, 60)}...`,
      url: session.url,
      elapsed: 0
    };
  }

  while (true) {
    const elapsed = Date.now() - startTime;
    
    if (elapsed > maxWaitMs) {
      console.log(`⏱️  Timeout reached for session ${sessionId}`);
      return {
        crash,
        sessionId,
        status: 'TIMEOUT',
        url: session.url,
        elapsed: Math.round(elapsed / 1000)
      };
    }
    
    try {
      const status = await getSessionStatus(sessionId);
      console.log(`   State: ${status.state} (${Math.round(elapsed / 1000)}s elapsed)`);
      
      if (status.state === 'COMPLETED') {
        // Check for PR output
        const prOutput = status.outputs?.find(o => o.pullRequest);
        if (prOutput) {
          const prUrl = prOutput.pullRequest.url;
          console.log(`✅ PR Created: ${prUrl}`);
          
          // Post Note back to Firebase Console
          if (appId) {
            const noteText = `✅ Jules AI has successfully created a Pull Request to fix this crash.\nPR URL: ${prUrl}`;
            await postCrashlyticsNote(appId, crash.id, noteText);
          }

          return {
            crash,
            sessionId,
            status: 'COMPLETED',
            prUrl: prUrl,
            prTitle: prOutput.pullRequest.title,
            url: session.url,
            elapsed: Math.round(elapsed / 1000)
          };
        } else {
          console.log(`✅ Completed (no PR created)`);
          return {
            crash,
            sessionId,
            status: 'COMPLETED_NO_PR',
            url: session.url,
            elapsed: Math.round(elapsed / 1000)
          };
        }
      } else if (status.state === 'FAILED') {
        console.log(`❌ Session failed`);
        return {
          crash,
          sessionId,
          status: 'FAILED',
          url: session.url,
          elapsed: Math.round(elapsed / 1000)
        };
      } else if (status.state === 'AWAITING_USER_FEEDBACK') {
        // Treat awaiting feedback as timeout if we've been waiting too long
        const timeoutReached = elapsed >= (maxWaitMinutes * 60 * 1000);
        if (timeoutReached) {
          console.log(`👤 Session awaiting user feedback - treating as timeout`);
          return {
            crash,
            sessionId,
            status: 'AWAITING_USER_FEEDBACK',
            url: session.url,
            elapsed: Math.round(elapsed / 1000),
            note: 'Session requires manual approval in Jules dashboard'
          };
        }
      }

      // Still in progress - wait before next check
      await new Promise(resolve => setTimeout(resolve, checkIntervalSeconds * 1000));
      
    } catch (error) {
      console.error(`Error checking session ${sessionId}:`, error.message);
      await new Promise(resolve => setTimeout(resolve, checkIntervalSeconds * 1000));
    }
  }
}

async function monitorAllSessions() {
  console.log(`\nStarting monitoring (timeout: ${maxWaitMinutes} minutes)...`);
  
  for (const sessionInfo of sessions) {
    const result = await monitorSession(sessionInfo);
    results.push(result);
  }
  
  // Save results
  try {
    fs.writeFileSync('session_results.json', JSON.stringify({ results }, null, 2));
    console.log('\n✅ Results saved to session_results.json');
  } catch (err) {
    console.error('⚠️  Warning: Failed to save results:', err.message);
  }

  // Print summary
  console.log('\n' + '='.repeat(50));
  console.log('📊 Monitoring Summary');
  console.log('='.repeat(50));

  const completed = results.filter(r => r.status === 'COMPLETED').length;
  const completedNoPr = results.filter(r => r.status === 'COMPLETED_NO_PR').length;
  const failed = results.filter(r => r.status === 'FAILED').length;
  const timeout = results.filter(r => r.status === 'TIMEOUT').length;
  const awaitingFeedback = results.filter(r => r.status === 'AWAITING_USER_FEEDBACK').length;

  console.log(`✅ PRs Created: ${completed}`);
  console.log(`✓  Completed (no PR): ${completedNoPr}`);
  console.log(`❌ Failed: ${failed}`);
  console.log(`⏱️  Timed Out: ${timeout}`);
  console.log(`👤 Awaiting Feedback: ${awaitingFeedback}`);
  console.log('');

  if (completed > 0) {
    console.log('Pull Requests Created:');
    results
      .filter(r => r.status === 'COMPLETED')
      .forEach(r => {
        console.log(`  - ${r.prUrl}`);
        console.log(`    ${r.crash.title}`);
      });
  }
}

monitorAllSessions()
  .then(() => {
    console.log('\n✅ Monitoring completed successfully');
    process.exit(0);
  })
  .catch(err => {
    console.error('\n❌ Monitoring failed:', err.message);
    process.exit(1);
  });
SCRIPT_EOF

# Execute monitoring script
echo "Starting session monitoring..."
node monitor_sessions.js

echo ""
echo "✅ Monitoring complete - results saved to session_results.json"
