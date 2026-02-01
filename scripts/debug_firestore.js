const admin = require('firebase-admin');

// Use application default credentials or environment variable
if (process.env.FIREBASE_CREDENTIALS) {
  const serviceAccount = JSON.parse(process.env.FIREBASE_CREDENTIALS);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} else {
  console.log('❌ FIREBASE_CREDENTIALS environment variable not set');
  console.log('💡 Run this from GitHub Actions or set the environment variable');
  process.exit(1);
}

admin.firestore().collection('app_config').doc('version_info').get()
  .then(doc => {
    console.log('📋 Firestore app_config/version_info:');
    const data = doc.data();
    console.log(JSON.stringify(data, null, 2));
    console.log('');
    console.log('🔍 Key fields:');
    console.log('  latestVersion:', data.latestVersion);
    console.log('  latestBuildNumber:', data.latestBuildNumber);
    console.log('  pendingRelease:', data.pendingRelease);
    console.log('  releaseDate:', data.releaseDate);
    console.log('  lastApprovedAt:', data.lastApprovedAt);
    console.log('');
    console.log('🧪 Debug Analysis:');
    console.log('  Current Play Store version: 3.25.2 (build 64)');
    console.log('  Firestore latestBuildNumber:', data.latestBuildNumber);
    console.log('  Match?', data.latestBuildNumber === 64);
    console.log('');
    console.log('📱 What users see:');
    console.log('  - Mobile version: < 3.25.2');
    console.log('  - Emulator version: 3.25.0');
    console.log('  - Should see popup if latestBuildNumber > their build number');
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ Error:', err.message);
    process.exit(1);
  });

