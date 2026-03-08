//
//  TAQALiveActivityExtension.swift
//  Runner
//
//  Created by Omar KHALIL on 3/8/26.
//

import WidgetKit
import SwiftUI
import ActivityKit

struct TAQALiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var secondsRemaining: Int
    }

    var workoutName: String
}

struct TAQALiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TAQALiveActivityAttributes.self) { context in
            VStack {
                Text(context.attributes.workoutName)
                Text(context.state.exerciseName)
                Text("\(context.state.secondsRemaining)s")
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.exerciseName)
                }
            } compactLeading: {
                Text("TAQA")
            } compactTrailing: {
                Text("\(context.state.secondsRemaining)")
            } minimal: {
                Text("T")
            }
        }
    }
}

@main
struct TAQALiveActivityExtensionBundle: WidgetBundle {
    var body: some Widget {
        TAQALiveActivityWidget()
    }
}
