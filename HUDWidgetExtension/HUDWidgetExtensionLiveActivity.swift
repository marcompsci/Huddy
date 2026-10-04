//
//  HUDWidgetExtensionLiveActivity.swift
//  HUDWidgetExtension
//
//  Created by Omari Bell on 10/2/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct HUDWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct HUDWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HUDWidgetExtensionAttributes.self) { context in
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

extension HUDWidgetExtensionAttributes {
    fileprivate static var preview: HUDWidgetExtensionAttributes {
        HUDWidgetExtensionAttributes(name: "World")
    }
}

extension HUDWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: HUDWidgetExtensionAttributes.ContentState {
        HUDWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: HUDWidgetExtensionAttributes.ContentState {
         HUDWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: HUDWidgetExtensionAttributes.preview) {
   HUDWidgetExtensionLiveActivity()
} contentStates: {
    HUDWidgetExtensionAttributes.ContentState.smiley
    HUDWidgetExtensionAttributes.ContentState.starEyes
}
