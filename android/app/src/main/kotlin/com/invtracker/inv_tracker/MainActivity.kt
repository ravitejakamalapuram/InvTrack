package com.invtracker.inv_tracker

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

// FlutterFragmentActivity is required for local_auth biometric dialogs to work
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.invtracker/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Screenshot restriction disabled by default globally - users can take screenshots generally.
        // We enable FLAG_SECURE dynamically for sensitive screens via MethodChannel.

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setSecureMode") {
                val secure = call.argument<Boolean>("secure") ?: false
                if (secure) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
