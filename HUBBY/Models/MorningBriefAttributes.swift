import Foundation
import ActivityKit

// App-side mirror of the widget extension's MorningBriefAttributes.
// Both modules must define this with identical Codable structure so ActivityKit
// can match the app-started activity to the widget extension's ActivityConfiguration.
struct MorningBriefAttributes: ActivityAttributes {
    var snapshotID: String

    struct ContentState: Codable, Hashable {
        var threatLevel: ThreatLevel   // uses main app's ThreatLevel (same raw values as widget copy)
        var headline: String
        var checking: Double
        var cardOwed: Double
        var topLeadTitle: String?
        var generatedAt: Date
    }
}
