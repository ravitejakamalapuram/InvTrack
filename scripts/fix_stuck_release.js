/**
 * Fix stuck release state in Firestore
 * 
 * This script manually sets pendingRelease=true so the workflow can run again
 * and update latestVersion/latestBuildNumber with the new logic.
 */

const admin = require('firebase-admin');

if (!process.env.FIREBASE_CREDENTIALS) {
  console.log('❌ FIREBASE_CREDENTIALS environment variable not set');
  console.log('💡 This script should be run from GitHub Actions workflow');
  console.log('');
  console.log('To run manually, export the secret:');
  console.log('  export FIREBASE_CREDENTIALS=$(cat path/to/service-account.json)');
  process.exit(1);
}

const serviceAccount = JSON.parse(process.env.FIREBASE_CREDENTIALS);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixStuckRelease() {
  try {
    console.log('🔧 Fixing stuck release state...\n');

    // Get current state
    const versionDoc = await db.collection('app_config').doc('version_info').get();
    const data = versionDoc.data();

    console.log('📋 Current Firestore state:');
    console.log('  latestVersion:', data.latestVersion);
    console.log('  latestBuildNumber:', data.latestBuildNumber);
    console.log('  pendingRelease:', data.pendingRelease);
    console.log('  pendingVersion:', data.pendingVersion);
    console.log('  pendingBuildNumber:', data.pendingBuildNumber);
    console.log('');

    // Set pendingRelease=true so workflow runs again
    await db.collection('app_config').doc('version_info').update({
      pendingRelease: true,
    });

    console.log('✅ Updated pendingRelease to true');
    console.log('');
    console.log('🚀 Next steps:');
    console.log('  1. Workflow will run on next schedule (or trigger manually)');
    console.log('  2. Workflow will detect approval and update Firestore');
    console.log('  3. Users will see update dialog after 30-minute delay');
    console.log('');
    console.log('To trigger workflow manually:');
    console.log('  gh workflow run check-playstore-approval.yml');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

fixStuckRelease();

