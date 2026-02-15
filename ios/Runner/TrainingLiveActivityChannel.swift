import Foundation
import Flutter
import ActivityKit

@available(iOS 16.1, *)
struct TrainingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var sets: Int
        var reps: Int
        var seconds: Int
    }

    var sessionId: String
}

@available(iOS 16.1, *)
final class TrainingLiveActivityChannel {
    private static var activity: Activity<TrainingActivityAttributes>?

    static func register(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(name: "training_live_activity", binaryMessenger: controller.binaryMessenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "start":
                Self.handleStart(call: call, result: result)
            case "update":
                Self.handleUpdate(call: call, result: result)
            case "stop":
                Self.handleStop(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func handleStart(call: FlutterMethodCall, result: FlutterResult) {
        guard #available(iOS 16.1, *) else {
            result(false)
            return
        }
        if !ActivityAuthorizationInfo().areActivitiesEnabled {
            result(false)
            return
        }
        guard let args = call.arguments as? [String: Any] else {
            result(false)
            return
        }
        let exerciseName = (args["exerciseName"] as? String) ?? "Training"
        let sets = (args["sets"] as? Int) ?? 0
        let reps = (args["reps"] as? Int) ?? 0
        let seconds = (args["seconds"] as? Int) ?? 0
        let sessionId = (args["sessionId"] as? String) ?? UUID().uuidString

        let attributes = TrainingActivityAttributes(sessionId: sessionId)
        let contentState = TrainingActivityAttributes.ContentState(
            exerciseName: exerciseName,
            sets: sets,
            reps: reps,
            seconds: seconds
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            print("[LiveActivity] started \(sessionId)")
            result(true)
        } catch {
            print("[LiveActivity] start failed: \(error.localizedDescription)")
            result(false)
        }
    }

    private static func handleUpdate(call: FlutterMethodCall, result: FlutterResult) {
        guard #available(iOS 16.1, *) else {
            result(false)
            return
        }
        guard let args = call.arguments as? [String: Any] else {
            result(false)
            return
        }
        guard let activity = activity else {
            result(false)
            return
        }
        let exerciseName = (args["exerciseName"] as? String) ?? "Training"
        let sets = (args["sets"] as? Int) ?? 0
        let reps = (args["reps"] as? Int) ?? 0
        let seconds = (args["seconds"] as? Int) ?? 0

        let contentState = TrainingActivityAttributes.ContentState(
            exerciseName: exerciseName,
            sets: sets,
            reps: reps,
            seconds: seconds
        )
        Task {
            await activity.update(using: contentState)
        }
        print("[LiveActivity] updated")
        result(true)
    }

    private static func handleStop(result: FlutterResult) {
        guard #available(iOS 16.1, *) else {
            result(false)
            return
        }
        guard let activity = activity else {
            result(true)
            return
        }
        Task {
            await activity.end(dismissalPolicy: .immediate)
            self.activity = nil
        }
        print("[LiveActivity] stopped")
        result(true)
    }
}
