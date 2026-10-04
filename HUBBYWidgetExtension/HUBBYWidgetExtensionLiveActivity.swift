import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity attributes

struct MorningBriefAttributes: ActivityAttributes {
    var snapshotID: String

    struct ContentState: Codable, Hashable {
        var threatLevel: ThreatLevel
        var headline: String
        var checking: Double
        var cardOwed: Double
        var topLeadTitle: String?
        var generatedAt: Date

        var isStale: Bool { Date().timeIntervalSince(generatedAt) > 93_600 }
    }
}

// MARK: - Lock Screen / notification bar

struct MorningBriefLockScreenBar: View {
    let context: ActivityViewContext<MorningBriefAttributes>

    private var state: MorningBriefAttributes.ContentState { context.state }
    private var threat: ThreatLevel { state.threatLevel }

    var body: some View {
        HStack(spacing: 12) {
            MiniGauge(checking: state.checking, cardOwed: state.cardOwed)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.headline)
                    .font(HUDFont.mono(11))
                    .foregroundStyle(Color.hudText)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(hudCurrency(state.checking))
                        .font(HUDFont.display(12))
                        .foregroundStyle(Color.hudGold)

                    Text("-" + hudCurrency(state.cardOwed))
                        .font(HUDFont.mono(11))
                        .foregroundStyle(Color.hudRed)

                    if state.isStale { StaleChip() }
                }
            }

            Spacer()

            Image(systemName: threat.systemIcon)
                .font(.title3)
                .foregroundStyle(threat.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(Color.panel)
        .activitySystemActionForegroundColor(Color.hudCyan)
    }
}

// MARK: - Widget declaration

struct MorningBriefLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MorningBriefAttributes.self) { context in
            MorningBriefLockScreenBar(context: context)
        } dynamicIsland: { context in
            let state = context.state
            let threat = state.threatLevel

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MiniGauge(checking: state.checking, cardOwed: state.cardOwed)
                        .frame(width: 54, height: 54)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(hudCurrency(state.checking))
                            .font(HUDFont.display(13))
                            .foregroundStyle(Color.hudGold)
                        Text("-" + hudCurrency(state.cardOwed))
                            .font(HUDFont.mono(11))
                            .foregroundStyle(Color.hudRed)
                    }
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(state.headline)
                        .font(HUDFont.mono(12))
                        .foregroundStyle(Color.hudText)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            } compactLeading: {
                Image(systemName: threat.systemIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(threat.color)
            } compactTrailing: {
                Text(hudCurrency(state.checking, cents: false))
                    .font(HUDFont.mono(11, weight: .medium))
                    .foregroundStyle(Color.hudGold)
                    .minimumScaleFactor(0.7)
            } minimal: {
                Image(systemName: threat.systemIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(threat.color)
            }
            .widgetURL(URL(string: "morninghud://home"))
            .keylineTint(Color.hudCyan)
        }
    }
}

// MARK: - Previews

private extension MorningBriefAttributes {
    static var previewAttrs: MorningBriefAttributes {
        MorningBriefAttributes(snapshotID: "preview")
    }
}

private extension MorningBriefAttributes.ContentState {
    static var previewState: MorningBriefAttributes.ContentState {
        MorningBriefAttributes.ContentState(
            threatLevel: .allClear,
            headline: "Cash flow positive. Two new leads in. No critical alerts.",
            checking: 2847.50,
            cardOwed: 342.18,
            topLeadTitle: "Senior iOS Developer",
            generatedAt: Date().addingTimeInterval(-1800)
        )
    }

    static var previewAlert: MorningBriefAttributes.ContentState {
        MorningBriefAttributes.ContentState(
            threatLevel: .alert,
            headline: "Low balance detected. Critical email flagged.",
            checking: 89.00,
            cardOwed: 1250.00,
            topLeadTitle: nil,
            generatedAt: Date().addingTimeInterval(-900)
        )
    }
}

#Preview("Live Activity", as: .content, using: MorningBriefAttributes.previewAttrs) {
    MorningBriefLiveActivity()
} contentStates: {
    MorningBriefAttributes.ContentState.previewState
    MorningBriefAttributes.ContentState.previewAlert
}
