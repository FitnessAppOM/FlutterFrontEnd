import ActivityKit
import WidgetKit
import SwiftUI

struct TrainingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var sets: Int
        var reps: Int
        var seconds: Int
    }

    var sessionId: String
}

struct TrainingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.state.exerciseName)
                    .font(.headline)
                Text("\(context.state.sets) x \(context.state.reps)")
                    .font(.subheadline)
                Text(formatTime(context.state.seconds))
                    .font(.title2)
                    .bold()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.exerciseName)
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.seconds))
                        .font(.caption)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.sets) x \(context.state.reps)")
                        .font(.caption2)
                }
            } compactLeading: {
                Text("TR")
            } compactTrailing: {
                Text(shortTime(context.state.seconds))
                    .monospacedDigit()
            } minimal: {
                Text(shortTime(context.state.seconds))
                    .monospacedDigit()
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func shortTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return "\(m)m\(s)"
    }
}

@main
struct TrainingLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TrainingLiveActivityWidget()
    }
}
