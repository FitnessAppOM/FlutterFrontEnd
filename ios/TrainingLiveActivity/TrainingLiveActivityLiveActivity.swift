import ActivityKit
import WidgetKit
import SwiftUI

struct TrainingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var sets: Int
        var reps: Int
        var seconds: Int
        var distanceKm: Double?
        var speedKmh: Double?
        var startMs: Int?
    }

    var sessionId: String
}

struct TrainingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingActivityAttributes.self) { context in
            TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                let elapsed = elapsedSeconds(from: context.state.startMs, now: timeline.date, fallback: context.state.seconds)
                let startDate = startDateFromMs(context.state.startMs, fallbackSeconds: elapsed, now: timeline.date)
                let timerText: Text = {
                    if let startDate {
                        return Text(startDate, style: .timer)
                    }
                    return Text(formatTime(elapsed))
                }()
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.10, blue: 0.12), Color(red: 0.02, green: 0.04, blue: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TaqaFitness")
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.75))
                                Text(context.state.exerciseName)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            Spacer()
                            timerText
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                        HStack(spacing: 8) {
                            if let dist = context.state.distanceKm, let speed = context.state.speedKmh {
                                badge(String(format: "%.2f km", dist))
                                badge(String(format: "%.1f km/h", speed))
                            } else {
                                badge("\(context.state.sets) sets")
                                badge("\(context.state.reps) reps")
                            }
                            Spacer()
                            Text("Live")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                                .foregroundStyle(Color.white.opacity(0.85))
                        }
                    }
                    .padding(14)
                }
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TaqaFitness")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.state.exerciseName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                        let elapsed = elapsedSeconds(from: context.state.startMs, now: timeline.date, fallback: context.state.seconds)
                        let startDate = startDateFromMs(context.state.startMs, fallbackSeconds: elapsed, now: timeline.date)
                        let timerText: Text = {
                            if let startDate {
                                return Text(startDate, style: .timer)
                            }
                            return Text(formatTime(elapsed))
                        }()
                        timerText
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        if let dist = context.state.distanceKm, let speed = context.state.speedKmh {
                            Text(String(format: "%.2f km", dist))
                            Text("•")
                            Text(String(format: "%.1f km/h", speed))
                        } else {
                            Text("\(context.state.sets) sets")
                            Text("•")
                            Text("\(context.state.reps) reps")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
            } compactTrailing: {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    let elapsed = elapsedSeconds(from: context.state.startMs, now: timeline.date, fallback: context.state.seconds)
                    let startDate = startDateFromMs(context.state.startMs, fallbackSeconds: elapsed, now: timeline.date)
                    let timerText: Text = {
                        if let startDate {
                            return Text(startDate, style: .timer)
                        }
                        return Text(shortTime(elapsed))
                    }()
                    timerText
                        .monospacedDigit()
                }
            } minimal: {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    let elapsed = elapsedSeconds(from: context.state.startMs, now: timeline.date, fallback: context.state.seconds)
                    let startDate = startDateFromMs(context.state.startMs, fallbackSeconds: elapsed, now: timeline.date)
                    let timerText: Text = {
                        if let startDate {
                            return Text(startDate, style: .timer)
                        }
                        return Text(shortTime(elapsed))
                    }()
                    timerText
                        .monospacedDigit()
                }
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
            .foregroundStyle(Color.white.opacity(0.9))
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

    private func elapsedSeconds(from startMs: Int?, now: Date, fallback: Int) -> Int {
        guard let startMs else { return fallback }
        let startDate = Date(timeIntervalSince1970: Double(startMs) / 1000.0)
        let elapsed = Int(now.timeIntervalSince(startDate))
        return max(0, elapsed)
    }

    private func startDateFromMs(_ startMs: Int?, fallbackSeconds: Int, now: Date) -> Date? {
        if let startMs {
            return Date(timeIntervalSince1970: Double(startMs) / 1000.0)
        }
        if fallbackSeconds > 0 {
            return now.addingTimeInterval(TimeInterval(-fallbackSeconds))
        }
        return nil
    }
}

@main
struct TrainingLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TrainingLiveActivityWidget()
    }
}
