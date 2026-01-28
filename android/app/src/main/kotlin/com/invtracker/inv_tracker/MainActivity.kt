package com.invtracker.inv_tracker

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity is required for local_auth biometric dialogs to work
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Prevent screenshots, screen recording, and app switcher previews in release builds
        // to protect sensitive financial data.
        // Note: Using ApplicationInfo.FLAG_DEBUGGABLE instead of BuildConfig.DEBUG because
        // BuildConfig may not be generated before Kotlin compilation in some build configurations.
        val isDebuggable = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
