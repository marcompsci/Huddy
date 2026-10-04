import WidgetKit
import SwiftUI

@main
struct HUBBYWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        MorningHUDWidget()
        MorningHUDAccessoryWidget()
        MorningBriefLiveActivity()
    }
}
