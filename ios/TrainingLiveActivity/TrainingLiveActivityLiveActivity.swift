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
        var paused: Bool
    }

    var sessionId: String
}

struct TrainingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingActivityAttributes.self) { context in
            TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                let elapsed = elapsedSeconds(from: context.state.startMs, now: timeline.date, fallback: context.state.seconds)
                let startDate = startDateFromMs(context.state.startMs, fallbackSeconds: elapsed, now: timeline.date, paused: context.state.paused)
                let timerText = timerView(
                    elapsed: elapsed,
                    startDate: startDate,
                    paused: context.state.paused,
                    short: false,
                    width: 72,
                    font: .system(size: 18, weight: .bold, design: .rounded)
                )
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
                        }
                        HStack(spacing: 8) {
                            if let dist = context.state.distanceKm, let speed = context.state.speedKmh {
                                badge(String(format: "%.2f km", dist))
                                badge(paceLabel(speed))
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
                        let startDate = startDateFromMs(context.state.startMs, fallbackSeconds: elapsed, now: timeline.date, paused: context.state.paused)
                        let timerText = timerView(
                            elapsed: elapsed,
                            startDate: startDate,
                            paused: context.state.paused,
                            short: false,
                            width: 52,
                            font: .caption
                        )
                        timerText
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        if let dist = context.state.distanceKm, let speed = context.state.speedKmh {
                            Text(String(format: "%.2f km", dist))
                            Text("•")
                            Text(paceLabel(speed))
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
                    let startDate = startDateFromMs(context.state.startMs, fallbackSeconds: elapsed, now: timeline.date, paused: context.state.paused)
                    let timerText = timerView(
                        elapsed: elapsed,
                        startDate: startDate,
                        paused: context.state.paused,
                        short: true,
                        width: 44,
                        font: .caption2
                    )
                    timerText
                }
            } minimal: {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    let elapsed = elapsedSeconds(from: context.state.startMs, now: timeline.date, fallback: context.state.seconds)
                    let startDate = startDateFromMs(context.state.startMs, fallbackSeconds: elapsed, now: timeline.date, paused: context.state.paused)
                    let timerText = timerView(
                        elapsed: elapsed,
                        startDate: startDate,
                        paused: context.state.paused,
                        short: true,
                        width: 44,
                        font: .caption2
                    )
                    timerText
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

    // NOTE: We now send pace (min/km) from Flutter, but keep the field name for compatibility.
    private func paceLabel(_ paceMinKm: Double) -> String {
        if paceMinKm <= 0.1 { return "--:-- /km" }
        let paceMin = paceMinKm
        let minutes = Int(paceMin)
        let rawSeconds = Int((paceMin - Double(minutes)) * 60.0)
        let seconds = max(0, min(59, rawSeconds))
        return String(format: "%02d:%02d /km", minutes, seconds)
    }

    private func elapsedSeconds(from startMs: Int?, now: Date, fallback: Int) -> Int {
        guard let startMs else { return fallback }
        let startDate = Date(timeIntervalSince1970: Double(startMs) / 1000.0)
        let elapsed = Int(now.timeIntervalSince(startDate))
        return max(0, elapsed)
    }

    private func startDateFromMs(_ startMs: Int?, fallbackSeconds: Int, now: Date, paused: Bool) -> Date? {
        if paused {
            return nil
        }
        if let startMs {
            return Date(timeIntervalSince1970: Double(startMs) / 1000.0)
        }
        if fallbackSeconds > 0 {
            return now.addingTimeInterval(TimeInterval(-fallbackSeconds))
        }
        return nil
    }

    private func timerView(
        elapsed: Int,
        startDate: Date?,
        paused: Bool,
        short: Bool,
        width: CGFloat,
        font: Font
    ) -> some View {
        let text: Text = {
            if paused {
                return Text(short ? shortTime(elapsed) : formatTime(elapsed))
            }
            if let startDate {
                return Text(startDate, style: .timer)
            }
            return Text(short ? shortTime(elapsed) : formatTime(elapsed))
        }()

        return text
            .font(font)
            .foregroundStyle(.white)
            .monospacedDigit()
            .frame(width: width, alignment: .trailing)
    }

}

@main
struct TrainingLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TrainingLiveActivityWidget()
    }
}
