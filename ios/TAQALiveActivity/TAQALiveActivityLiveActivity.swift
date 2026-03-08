//
//  TAQALiveActivityLiveActivity.swift
//  TAQALiveActivity
//
//  Created by Omar KHALIL on 3/8/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TAQALiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TAQALiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TAQALiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TAQALiveActivityAttributes {
    fileprivate static var preview: TAQALiveActivityAttributes {
        TAQALiveActivityAttributes(name: "World")
    }
}

extension TAQALiveActivityAttributes.ContentState {
    fileprivate static var smiley: TAQALiveActivityAttributes.ContentState {
        TAQALiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TAQALiveActivityAttributes.ContentState {
         TAQALiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TAQALiveActivityAttributes.preview) {
   TAQALiveActivityLiveActivity()
} contentStates: {
    TAQALiveActivityAttributes.ContentState.smiley
    TAQALiveActivityAttributes.ContentState.starEyes
}
