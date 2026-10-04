import WidgetKit
import SwiftUI

// MARK: - Shared data model (mirrors WidgetData in the app)
// Add this file to the MorningHUDWidget target. It intentionally does NOT
// import app types — the widget decodes just what it needs.

private let kAppGroup = "group.com.omari.morninghud"

struct WData: Codable {
    var checking: Double?
    var cardOwed: Double?
    var threatLevel: String?   // "ALERT", "WATCH", "ALL CLEAR"
    var headline: String?
    var topLeadPayText: String?
    var topLeadTitle: String?
    var generatedAt: Date?
}

private func loadWidgetData() -> WData {
    guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup),
          let data = try? Data(contentsOf: container.appendingPathComponent("WidgetData.json")),
          let w = try? JSONDecoder().decode(WData.self, from: data) else {
        return WData(checking: 0, cardOwed: 0, threatLevel: "ALL CLEAR",
                     headline: "No data — open app to refresh", topLeadPayText: nil,
                     topLeadTitle: nil, generatedAt: nil)
    }
    return w
}

// MARK: - Colors (match Theme.swift hex values, no import needed)

private let voidColor  = Color(red: 5/255,   green: 9/255,   blue: 14/255)
private let panelColor = Color(red: 10/255,  green: 18/255,  blue: 26/255)
private let cyanColor  = Color(red: 95/255,  green: 227/255, blue: 255/255)
private let goldColor  = Color(red: 245/255, green: 184/255, blue: 65/255)
private let redColor   = Color(red: 255/255, green: 83/255,  blue: 64/255)
private let greenColor = Color(red: 91/255,  green: 240/255, blue: 165/255)
private let textColor  = Color(red: 214/255, green: 232/255, blue: 240/255)
private let dimColor   = Color(red: 124/255, green: 149/255, blue: 163/255)

private func threatColor(_ level: String?) -> Color {
    switch level {
    case "ALERT": return redColor
    case "WATCH": return goldColor
    default:      return greenColor
    }
}

private func formatCurrency(_ v: Double?) -> String {
    guard let v else { return "—" }
    let f = NumberFormatter(); f.numberStyle = .currency; f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: v)) ?? "$\(Int(v))"
}

// MARK: - Timeline entry

struct HUDEntry: TimelineEntry {
    let date: Date
    let data: WData
}

// MARK: - Provider

struct HUDProvider: TimelineProvider {
    func placeholder(in context: Context) -> HUDEntry {
        HUDEntry(date: Date(), data: WData(checking: 609.95, cardOwed: 296.81,
                 threatLevel: "ALL CLEAR", headline: "Nothing new worth flagging.",
                 topLeadPayText: "$8,000 / mo", topLeadTitle: "Coach", generatedAt: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (HUDEntry) -> Void) {
        completion(HUDEntry(date: Date(), data: loadWidgetData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HUDEntry>) -> Void) {
        let entry = HUDEntry(date: Date(), data: loadWidgetData())
        // Refresh every 30 minutes; the app rewrites WidgetData.json on each refresh
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Small widget

struct SmallHUDView: View {
    let entry: HUDEntry
    var body: some View {
        ZStack {
            voidColor
            VStack(spacing: 6) {
                Circle()
                    .stroke(threatColor(entry.data.threatLevel), lineWidth: 4)
                    .frame(width: 52, height: 52)
                    .overlay(
                        VStack(spacing: 1) {
                            Text("CHKG").font(.system(size: 8, design: .monospaced)).foregroundStyle(dimColor)
                            Text(formatCurrency(entry.data.checking))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(threatColor(entry.data.threatLevel))
                                .minimumScaleFactor(0.6)
                        }
                    )
                Text(entry.data.threatLevel ?? "—")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(threatColor(entry.data.threatLevel))
                    .kerning(1)
            }
        }
        .containerBackground(voidColor, for: .widget)
    }
}

// MARK: - Medium widget

struct MediumHUDView: View {
    let entry: HUDEntry
    var body: some View {
        ZStack {
            voidColor
            HStack(spacing: 12) {
                // Gauge column
                VStack(spacing: 4) {
                    Circle()
                        .stroke(threatColor(entry.data.threatLevel), lineWidth: 5)
                        .frame(width: 64, height: 64)
                        .overlay(
                            VStack(spacing: 2) {
                                Text("CHKG").font(.system(size: 7, design: .monospaced)).foregroundStyle(dimColor)
                                Text(formatCurrency(entry.data.checking))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(threatColor(entry.data.threatLevel))
                                    .minimumScaleFactor(0.5)
                            }
                        )
                    Text(entry.data.threatLevel ?? "—")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(threatColor(entry.data.threatLevel))
                        .kerning(1)
                }

                // Info column
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.data.headline ?? "—")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(textColor)
                        .lineLimit(2)
                    if let payText = entry.data.topLeadPayText {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TOP LEAD").font(.system(size: 8, design: .monospaced)).foregroundStyle(dimColor).kerning(1)
                            Text(payText).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(goldColor)
                            if let title = entry.data.topLeadTitle {
                                Text(title).font(.system(size: 9, design: .monospaced)).foregroundStyle(dimColor).lineLimit(1)
                            }
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        }
        .containerBackground(voidColor, for: .widget)
    }
}

// MARK: - Lock-screen inline

struct InlineHUDView: View {
    let entry: HUDEntry
    var body: some View {
        let icon = entry.data.threatLevel == "ALERT" ? "!" : "✓"
        let level = entry.data.threatLevel ?? "CLEAR"
        let bal   = formatCurrency(entry.data.checking)
        Text("\(icon) \(level) · \(bal)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
    }
}

// MARK: - Widget bundle entry point

struct MorningHUDWidget: Widget {
    let kind = "MorningHUDWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HUDProvider()) { entry in
            SmallHUDView(entry: entry)
        }
        .configurationDisplayName("Morning HUD")
        .description("Checking balance and threat level.")
        .supportedFamilies([.systemSmall])
    }
}

struct MorningHUDMediumWidget: Widget {
    let kind = "MorningHUDMediumWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HUDProvider()) { entry in
            MediumHUDView(entry: entry)
        }
        .configurationDisplayName("Morning HUD")
        .description("Balance, threat level, headline and top lead.")
        .supportedFamilies([.systemMedium])
    }
}

struct MorningHUDInlineWidget: Widget {
    let kind = "MorningHUDInlineWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HUDProvider()) { entry in
            InlineHUDView(entry: entry)
        }
        .configurationDisplayName("Morning HUD")
        .description("Compact lock-screen status.")
        .supportedFamilies([.accessoryInline])
    }
}

@main
struct MorningHUDWidgetBundle: WidgetBundle {
    var body: some Widget {
        MorningHUDWidget()
        MorningHUDMediumWidget()
        MorningHUDInlineWidget()
    }
}
