# Ad Integration Implementation Guide

**Complete Step-by-Step Implementation for InvTrack**

---

## 📋 **Phase 1: Setup & Dependencies (Day 1)**

### **1.1: Install Package**

✅ **DONE**: Added `google_mobile_ads: ^5.2.0` to `pubspec.yaml`

```bash
flutter pub get
```

### **1.2: Configure Android**

**File**: `android/app/src/main/AndroidManifest.xml`

Add inside `<application>` tag:

```xml
<application>
    <!-- Existing config... -->
    
    <!-- Google Mobile Ads App ID -->
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-3940256099942544~3347511713"/>
    
    <!-- Replace with your actual AdMob App ID in production -->
    <!-- android:value="ca-app-pub-YOUR_PUBLISHER_ID~YOUR_APP_ID"/> -->
</application>
```

### **1.3: Configure iOS**

**File**: `ios/Runner/Info.plist`

Add before `</dict>`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>

<!-- Replace with your actual AdMob App ID in production -->
<!-- <string>ca-app-pub-YOUR_PUBLISHER_ID~YOUR_APP_ID</string> -->

<!-- SKAdNetwork identifiers for ad networks -->
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
    <!-- Add more ad networks as needed -->
</array>
```

### **1.4: Initialize Ad Service in main.dart**

**File**: `lib/main.dart`

Modify `_initializeNonCriticalServices()`:

```dart
Future<void> _initializeNonCriticalServices(
  NotificationService notificationService,
) async {
  try {
    // ... existing initialization
    
    // Initialize Ad Service (NEW)
    final prefs = await SharedPreferences.getInstance();
    final analytics = AnalyticsService();
    final adService = AdService(prefs: prefs, analytics: analytics);
    unawaited(adService.initialize());
    
    LoggerService.info('Ad service initialized');
  } catch (e) {
    // ... existing error handling
  }
}
```

---

## 📋 **Phase 2: Create Native Ad Template (Day 1-2)**

### **2.1: Android Native Ad Layout**

**File**: `android/app/src/main/res/layout/native_ad_layout.xml` (CREATE NEW)

```xml
<?xml version="1.0" encoding="utf-8"?>
<com.google.android.gms.ads.nativead.NativeAdView xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:background="@android:color/transparent">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical"
        android:padding="16dp">

        <!-- Ad Icon -->
        <com.google.android.gms.ads.nativead.MediaView
            android:id="@+id/ad_media"
            android:layout_width="match_parent"
            android:layout_height="200dp"
            android:layout_marginBottom="8dp" />

        <!-- Ad Headline -->
        <TextView
            android:id="@+id/ad_headline"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:textSize="16sp"
            android:textStyle="bold"
            android:textColor="?android:attr/textColorPrimary"
            android:maxLines="2"
            android:ellipsize="end"
            android:layout_marginBottom="4dp" />

        <!-- Ad Body -->
        <TextView
            android:id="@+id/ad_body"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:textSize="14sp"
            android:textColor="?android:attr/textColorSecondary"
            android:maxLines="3"
            android:ellipsize="end"
            android:layout_marginBottom="8dp" />

        <!-- Call to Action Button -->
        <Button
            android:id="@+id/ad_call_to_action"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:textSize="14sp"
            android:textColor="@android:color/white"
            android:background="@android:color/holo_blue_light" />
    </LinearLayout>
</com.google.android.gms.ads.nativead.NativeAdView>
```

### **2.2: Register Native Ad Factory (Android)**

**File**: `android/app/src/main/kotlin/com/invtracker/inv_tracker/MainActivity.kt`

```kotlin
package com.invtracker.inv_tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import android.view.LayoutInflater
import android.widget.TextView
import android.widget.Button

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register native ad factory
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "investmentListNativeAd",
            InvestmentListNativeAdFactory(layoutInflater)
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "investmentListNativeAd")
    }
}

class InvestmentListNativeAdFactory(private val layoutInflater: LayoutInflater) :
    GoogleMobileAdsPlugin.NativeAdFactory {
    
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.native_ad_layout, null) as NativeAdView
        
        // Bind ad components
        adView.headlineView = adView.findViewById(R.id.ad_headline)
        adView.bodyView = adView.findViewById(R.id.ad_body)
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        adView.mediaView = adView.findViewById(R.id.ad_media)
        
        // Populate ad views with data
        (adView.headlineView as TextView).text = nativeAd.headline
        (adView.bodyView as TextView).text = nativeAd.body
        (adView.callToActionView as Button).text = nativeAd.callToAction
        
        adView.setNativeAd(nativeAd)
        
        return adView
    }
}
```

---

## 📋 **Phase 3: Integrate into Investment List (Day 2-3)**

### **3.1: Modify InvestmentListScreen**

**File**: `lib/features/investment/presentation/screens/investment_list_screen.dart`

Add imports at top:

```dart
import 'package:inv_tracker/core/ads/ad_provider.dart';
import 'package:inv_tracker/core/ads/ad_placement_strategy.dart';
import 'package:inv_tracker/core/widgets/native_ad_widget.dart';
```

Modify the `SliverList` builder (around line 393):

```dart
return SliverPadding(
  padding: EdgeInsets.all(AppSpacing.md),
  sliver: SliverList(
    delegate: SliverChildBuilderDelegate(
      (context, index) {
        // Calculate ad positions
        final adPositions = AdPlacementStrategy.getInvestmentListAdPositions(
          filteredInvestments.length,
        );

        // Check if current position should show an ad
        final isAdPosition = adPositions.contains(index);

        if (isAdPosition) {
          // Show ad at this position
          return _buildAdWidget(ref);
        }

        // Adjust index for actual investment (account for ads)
        final adsBeforeThisIndex = adPositions.where((pos) => pos < index).length;
        final investmentIndex = index - adsBeforeThisIndex;

        // Bounds check
        if (investmentIndex >= filteredInvestments.length) {
          return const SizedBox.shrink();
        }

        final investment = filteredInvestments[investmentIndex];
        final isArchived = investment.isArchived;

        // ... existing InvestmentCard code
        return StaggeredFadeIn(
          index: investmentIndex,
          child: RepaintBoundary(
            child: SwipeActions(
              // ... existing SwipeActions config
              child: InvestmentCard(
                investment: investment,
                // ... existing card config
              ),
            ),
          ),
        );
      },
      // Update child count to include ads
      childCount: filteredInvestments.length +
          AdPlacementStrategy.getInvestmentListAdPositions(
            filteredInvestments.length,
          ).length,
    ),
  ),
);
```

Add helper method to build ad widget:

```dart
Widget _buildAdWidget(WidgetRef ref) {
  final shouldShowAds = ref.watch(shouldShowAdsProvider);

  if (!shouldShowAds) {
    return const SizedBox.shrink();
  }

  final adState = ref.watch(
    nativeAdProvider(AdPlacement.investmentList),
  );

  // Load ad if not loaded yet
  if (!adState.hasAd && !adState.isLoading && !adState.hasError) {
    Future.microtask(() {
      ref
          .read(nativeAdProvider(AdPlacement.investmentList).notifier)
          .loadAd();
    });
  }

  if (adState.hasAd) {
    return NativeAdWidget(adState: adState);
  } else if (adState.isLoading) {
    return const NativeAdLoadingWidget();
  } else if (adState.hasError) {
    return const NativeAdErrorWidget();
  }

  return const SizedBox.shrink();
}
```

---

## 📋 **Phase 4: Testing & Validation (Day 3)**

### **4.1: Test Ad Loading**

**Run in debug mode** (uses Google test ads):

```bash
flutter run --debug
```

**Expected Behavior**:
1. App loads normally
2. Navigate to Investment List
3. Scroll down to 10th investment
4. See test native ad (Google test creative)
5. Ad blends with InvTrack UI (matches theme)
6. "Ad" label visible in top-left corner

### **4.2: Test Ad-Free Scenarios**

**Test consent denial**:
1. Modify `AdService.requestConsent()` to return `AdConsentStatus.denied`
2. Rebuild app
3. Verify NO ads appear in Investment List

**Test grace period**:
1. Modify `AdService._isInGracePeriod()` to return `true`
2. Rebuild app
3. Verify NO ads appear

### **4.3: Test Analytics**

Check Firebase Analytics debugView for:
- `ad_service_initialized` event
- `ad_loaded` event (when ad loads successfully)
- `ad_load_failed` event (when ad fails)
- `ad_impression` event (when ad is viewed)
- `ad_clicked` event (when user taps ad)

### **4.4: Performance Testing**

**Metrics to verify**:
- [ ] Investment list scrolls smoothly (60fps)
- [ ] Ad load doesn't block UI (async loading)
- [ ] Ad widget is RepaintBoundary isolated
- [ ] Memory usage stable (<50MB increase with ads)
- [ ] No jank when scrolling past ads

---

## 📋 **Phase 5: Production Deployment (Day 4)**

### **5.1: Create AdMob Account**

1. Sign up at https://admob.google.com
2. Create new app (Android + iOS)
3. Create 3 ad units:
   - "InvTrack - Investment List" (Native Advanced)
   - "InvTrack - Portfolio Health" (Native Advanced)
   - "InvTrack - Goals" (Native Advanced)
4. Copy ad unit IDs

### **5.2: Replace Test Ad Unit IDs**

**File**: `lib/core/ads/ad_service.dart`

```dart
String _getAdUnitId(AdPlacement placement) {
  if (kDebugMode) {
    return 'ca-app-pub-3940256099942544/2247696110'; // Test ID
  }

  switch (placement) {
    case AdPlacement.investmentList:
      return 'ca-app-pub-1234567890/1111111111'; // REPLACE
    case AdPlacement.portfolioHealth:
      return 'ca-app-pub-1234567890/2222222222'; // REPLACE
    case AdPlacement.goalList:
      return 'ca-app-pub-1234567890/3333333333'; // REPLACE
  }
}
```

### **5.3: Update AndroidManifest.xml**

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-1234567890~1234567890"/> <!-- REPLACE -->
```

### **5.4: Update iOS Info.plist**

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-1234567890~0987654321</string> <!-- REPLACE -->
```

### **5.5: Build Release APK**

```bash
flutter build apk --release
flutter build appbundle --release
```

### **5.6: Test in Production**

**IMPORTANT**: Real ads take 1-2 hours to appear after first release.

1. Install release APK on device
2. Scroll to Investment List position 10
3. Wait 10-30 seconds for ad to load
4. Verify ad appears (not test ad)

---

## 📋 **Phase 6: Monitoring & Optimization (Ongoing)**

### **6.1: Monitor AdMob Dashboard**

**Daily metrics**:
- Impressions (how many ads shown)
- CTR (click-through rate) - Target: >1%
- eCPM (revenue per 1000 impressions) - Target: >₹50
- Fill rate (% of ad requests filled) - Target: >80%

### **6.2: A/B Test Ad Frequency**

**Experiment 1**: Ad every 10 investments (baseline)
**Experiment 2**: Ad every 15 investments (less intrusive)
**Experiment 3**: Ad every 7 investments (more revenue)

**Measure**: Revenue vs User Retention (7-day)

### **6.3: Optimize Ad Placement**

**Low-performing placements** (CTR <0.5%):
- Consider removing or repositioning
- Try different ad formats
- Adjust ad styling

**High-performing placements** (CTR >2%):
- Keep as-is
- Consider adding similar placements

---

## 📋 **Acceptance Criteria Checklist**

- [ ] `google_mobile_ads` dependency added
- [ ] Android/iOS manifest updated with AdMob App ID
- [ ] Ad service initialized in main.dart
- [ ] Native ad factory registered (Android/iOS)
- [ ] Investment List shows ad every 10 investments
- [ ] Ad matches InvTrack UI theme (light/dark mode)
- [ ] "Ad" label visible on all ads
- [ ] GDPR consent dialog implemented
- [ ] Ad-free grace period (first 7 days)
- [ ] Analytics events firing correctly
- [ ] Performance: 60fps scroll with ads
- [ ] Production ad unit IDs configured
- [ ] Real ads appearing in release build

---

## 🚀 **Next Steps After Investment List**

1. **Portfolio Health Screen** (similar integration)
2. **Goals Screen** (similar integration)
3. **Implement GDPR Consent Dialog** (using User Messaging Platform SDK)
4. **Add "Remove Ads" Premium Feature** (₹99/month subscription)

---

**Status**: ✅ **Ready for Implementation** - Follow this guide step-by-step for production-ready ad integration.

