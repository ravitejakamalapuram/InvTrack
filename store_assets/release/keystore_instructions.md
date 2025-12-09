# Release Keystore Setup

## Step 1: Generate Keystore

Run this command to create your upload keystore:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

You'll be prompted for:
- Keystore password (remember this!)
- Your name, organization, location
- Key password (can be same as keystore password)

## Step 2: Create key.properties

Create `android/key.properties` with your keystore info:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/YOUR_USERNAME/upload-keystore.jks
```

⚠️ **IMPORTANT**: Add `key.properties` to `.gitignore`!

## Step 3: Configure build.gradle

Edit `android/app/build.gradle`:

```gradle
// Add before android block
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

## Step 4: Build Release Bundle

```bash
flutter build appbundle --release
```

The bundle will be at:
`build/app/outputs/bundle/release/app-release.aab`

## Step 5: Upload to Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Create new app or select existing
3. Go to Release > Production
4. Upload the `.aab` file
5. Complete store listing with assets from this folder

## Backup Your Keystore!

⚠️ **CRITICAL**: Backup your keystore file and passwords securely!
- If you lose the keystore, you cannot update your app
- Store in a password manager or secure location
- Never commit to version control

