import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 16.1, *) {
      if let controller = window?.rootViewController as? FlutterViewController {
        TrainingLiveActivityChannel.register(with: controller)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
