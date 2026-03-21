import Flutter
import UIKit
import UserNotifications
import HealthKit

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
      HealthWorkoutMetadataChannel.register(with: controller)
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

class HealthWorkoutMetadataChannel {
  private static let healthStore = HKHealthStore()

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "health_workout_metadata",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "writeWorkoutWithMetadata":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "Missing args", details: nil))
          return
        }
        writeWorkoutWithMetadata(arguments: args, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func writeWorkoutWithMetadata(
    arguments: [String: Any],
    result: @escaping FlutterResult
  ) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(false)
      return
    }

    guard let activityTypeName = arguments["activityType"] as? String,
      let startMs = asDouble(arguments["startTime"]),
      let endMs = asDouble(arguments["endTime"])
    else {
      result(FlutterError(code: "bad_args", message: "Missing workout fields", details: nil))
      return
    }

    let start = Date(timeIntervalSince1970: startMs / 1000.0)
    let end = Date(timeIntervalSince1970: endMs / 1000.0)
    if end <= start {
      result(false)
      return
    }

    let activityType = hkWorkoutActivityType(from: activityTypeName)
    let energyUnitName = arguments["totalEnergyBurnedUnit"] as? String
    let distanceUnitName = arguments["totalDistanceUnit"] as? String
    let totalEnergyBurned = hkQuantity(
      value: arguments["totalEnergyBurned"],
      unitName: energyUnitName,
      fallbackUnit: .kilocalorie()
    )
    let totalDistance = hkQuantity(
      value: arguments["totalDistance"],
      unitName: distanceUnitName,
      fallbackUnit: .meter()
    )

    var metadata: [String: Any] = [:]
    if let brandName = (arguments["workoutBrandName"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !brandName.isEmpty
    {
      metadata[HKMetadataKeyWorkoutBrandName] = brandName
    }
    if let indoor = arguments["isIndoorWorkout"] as? Bool {
      metadata[HKMetadataKeyIndoorWorkout] = indoor
    }
    if let externalUuid = (arguments["externalUuid"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !externalUuid.isEmpty
    {
      metadata[HKMetadataKeyExternalUUID] = externalUuid
      metadata["TAQA_CLIENT_ID_WORKOUT_METADATA_KEY"] = externalUuid
    }
    if let title = (arguments["title"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !title.isEmpty
    {
      metadata["TAQA_WORKOUT_TITLE"] = title
    }

    let workout = HKWorkout(
      activityType: activityType,
      start: start,
      end: end,
      duration: end.timeIntervalSince(start),
      totalEnergyBurned: totalEnergyBurned,
      totalDistance: totalDistance,
      metadata: metadata.isEmpty ? nil : metadata
    )

    let shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]
    healthStore.requestAuthorization(toShare: shareTypes, read: nil) { granted, _ in
      if !granted {
        DispatchQueue.main.async {
          result(false)
        }
        return
      }
      healthStore.save(workout) { success, _ in
        DispatchQueue.main.async {
          result(success)
        }
      }
    }
  }

  private static func hkQuantity(
    value: Any?,
    unitName: String?,
    fallbackUnit: HKUnit
  ) -> HKQuantity? {
    guard let value else { return nil }
    let numericValue: Double?
    if let d = value as? Double {
      numericValue = d
    } else if let i = value as? Int {
      numericValue = Double(i)
    } else if let n = value as? NSNumber {
      numericValue = n.doubleValue
    } else if let s = value as? String {
      numericValue = Double(s)
    } else {
      numericValue = nil
    }
    guard let numeric = numericValue else { return nil }
    let unit = hkUnit(from: unitName, fallback: fallbackUnit)
    return HKQuantity(unit: unit, doubleValue: numeric)
  }

  private static func asDouble(_ value: Any?) -> Double? {
    if let d = value as? Double { return d }
    if let i = value as? Int { return Double(i) }
    if let n = value as? NSNumber { return n.doubleValue }
    if let s = value as? String { return Double(s) }
    return nil
  }

  private static func hkUnit(from name: String?, fallback: HKUnit) -> HKUnit {
    guard let key = name?.uppercased() else { return fallback }
    switch key {
    case "KILOCALORIE":
      return .kilocalorie()
    case "CALORIE":
      return .calorie()
    case "METER":
      return .meter()
    case "KILOMETER":
      return .meterUnit(with: .kilo)
    default:
      return fallback
    }
  }

  private static func hkWorkoutActivityType(from name: String) -> HKWorkoutActivityType {
    switch name.uppercased() {
    case "RUNNING":
      return .running
    case "WALKING":
      return .walking
    case "BIKING":
      return .cycling
    case "ROWING":
      return .rowing
    case "SWIMMING":
      return .swimming
    case "HIGH_INTENSITY_INTERVAL_TRAINING":
      return .highIntensityIntervalTraining
    case "ELLIPTICAL":
      return .elliptical
    case "BOXING":
      return .boxing
    case "KICKBOXING":
      return .kickboxing
    case "SKATING":
      return .skatingSports
    case "JUMP_ROPE":
      return .jumpRope
    case "STAIR_CLIMBING":
      return .stairClimbing
    case "TRADITIONAL_STRENGTH_TRAINING":
      return .traditionalStrengthTraining
    default:
      return .traditionalStrengthTraining
    }
  }
}
