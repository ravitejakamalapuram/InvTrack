import Darwin
import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var blurView: UIVisualEffectView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.invtracker/security",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "elapsedRealtime":
          var timebase = mach_timebase_info_data_t()
          guard mach_timebase_info(&timebase) == KERN_SUCCESS else {
            result(
              FlutterError(
                code: "CLOCK_UNAVAILABLE",
                message: "Could not read the continuous clock",
                details: nil
              )
            )
            return
          }

          let ticks = mach_continuous_time()
          let nanos = Double(ticks) * Double(timebase.numer) / Double(timebase.denom)
          result(Int64(nanos / 1_000_000))
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    if blurView == nil {
      let blurEffect = UIBlurEffect(style: .regular)
      blurView = UIVisualEffectView(effect: blurEffect)
      blurView?.frame = window?.frame ?? UIScreen.main.bounds
      if let blurView = blurView {
        window?.addSubview(blurView)
      }
    }
    super.applicationWillResignActive(application)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    blurView?.removeFromSuperview()
    blurView = nil
    super.applicationDidBecomeActive(application)
  }
}
