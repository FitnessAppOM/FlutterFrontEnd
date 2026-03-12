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
    if let controller = window?.rootViewController as? FlutterViewController {
      InstagramShareChannel.register(with: controller)
      if #available(iOS 16.1, *) {
        TrainingLiveActivityChannel.register(with: controller)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class InstagramShareChannel {
  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "instagram_share",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "shareSticker":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "Missing args", details: nil))
          return
        }
        guard let imageData = (args["image"] as? FlutterStandardTypedData)?.data else {
          result(FlutterError(code: "bad_image", message: "Missing image bytes", details: nil))
          return
        }
        let appId = (args["appId"] as? String) ?? ""
        if appId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          result(FlutterError(code: "no_app_id", message: "Missing Instagram app ID", details: nil))
          return
        }
        let encodedAppId = appId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? appId
        guard let url = URL(
          string: "instagram-stories://share?source_application=\(encodedAppId)"
        ) else {
          result(FlutterError(code: "bad_url", message: "Invalid URL", details: nil))
          return
        }
        DispatchQueue.main.async {
          print("[IGShare] opening \(url.absoluteString) bytes=\(imageData.count)")
          if !UIApplication.shared.canOpenURL(url) {
            result(FlutterError(code: "unavailable", message: "Instagram not available", details: nil))
            return
          }
          let items: [String: Any] = [
            "com.instagram.sharedSticker.stickerImage": imageData
          ]
          UIPasteboard.general.setItems(
            [items],
            options: [.expirationDate: Date().addingTimeInterval(300)]
          )
          UIApplication.shared.open(url, options: [:]) { success in
            if success {
              result(true)
            } else {
              result(FlutterError(code: "open_failed", message: "Failed to open Instagram", details: nil))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
