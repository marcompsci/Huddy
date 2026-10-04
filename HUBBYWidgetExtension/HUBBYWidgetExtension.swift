import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Snapshot store (widget side, reads WidgetData.json from App Group)

actor SnapshotStore {
    static let shared = SnapshotStore()

    func load() -> WidgetData? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: kWidgetAppGroup)
        else { return nil }
        let url = container.appendingPathComponent("WidgetData.json")
        guard let raw = try? Data(contentsOf: url) else { return nil }
        return try? WidgetData.decoder.decode(WidgetData.self, from: raw)
    }
}

// MARK: - Timeline entry

struct HUDEntry: TimelineEntry {
    var date: Date
    var data: WidgetData?
    var config: HUDWidgetConfig
}

// MARK: - Focus mode

enum FocusMode: String, AppEnum, CaseIterable {
    case balanced   = "balanced"
    case moneyFirst = "moneyFirst"
    case leadsFirst = "leadsFirst"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Focus Mode")
    static var caseDisplayRepresentations: [FocusMode: DisplayRepresentation] = [
        .balanced:   "Balanced",
        .moneyFirst: "Money First",
        .leadsFirst: "Leads First"
    ]
}

// MARK: - Widget configuration intent

struct HUDWidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Morning HUD"
    static var description = IntentDescription("Customize your widget display.")

    @Parameter(title: "Focus", default: FocusMode.balanced)
    var focus: FocusMode

    @Parameter(title: "Show Cents", default: false)
    var showDollarCents: Bool

    init() {}
    init(focus: FocusMode = .balanced, showDollarCents: Bool = false) {
        self.focus = focus
        self.showDollarCents = showDollarCents
    }
}

// MARK: - Refresh intent (interactive ↻ button)

struct RefreshSnapshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh HUD"
    static var description = IntentDescription("Reload Morning HUD widget data.")
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Timeline provider

struct HUDProvider: AppIntentTimelineProvider {
    typealias Entry = HUDEntry
    typealias Intent = HUDWidgetConfig

    func placeholder(in context: Context) -> HUDEntry {
        HUDEntry(date: .now, data: nil, config: HUDWidgetConfig())
    }

    func snapshot(for configuration: HUDWidgetConfig, in context: Context) async -> HUDEntry {
        let data = await SnapshotStore.shared.load()
        return HUDEntry(date: .now, data: data, config: configuration)
    }

    func timeline(for configuration: HUDWidgetConfig, in context: Context) async -> Timeline<HUDEntry> {
        let data = await SnapshotStore.shared.load()
        let now = Date()
        var entries: [HUDEntry] = [HUDEntry(date: now, data: data, config: configuration)]

        // 30-min intervals × 4 (covers next 2 hours)
        for i in 1...4 {
            if let d = Calendar.current.date(byAdding: .minute, value: 30 * i, to: now) {
                entries.append(HUDEntry(date: d, data: data, config: configuration))
            }
        }

        // 6:10 AM entry the following morning
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
        comps.hour = 6; comps.minute = 10; comps.second = 0
        if let morning = Calendar.current.date(from: comps) {
            let target = morning > now
                ? morning
                : Calendar.current.date(byAdding: .day, value: 1, to: morning) ?? morning
            entries.append(HUDEntry(date: target, data: data, config: configuration))
        }

        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Shared components

struct WidgetCornerBrackets: View {
    var color: Color = .hudCyan
    var len: CGFloat = 8

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let corners: [[CGPoint]] = [
                [.init(x: 0, y: len),     .init(x: 0, y: 0),   .init(x: len, y: 0)],
                [.init(x: w - len, y: 0), .init(x: w, y: 0),   .init(x: w, y: len)],
                [.init(x: 0, y: h - len), .init(x: 0, y: h),   .init(x: len, y: h)],
                [.init(x: w - len, y: h), .init(x: w, y: h),   .init(x: w, y: h - len)]
            ]
            for pts in corners {
                var p = Path()
                p.move(to: pts[0])
                for pt in pts.dropFirst() { p.addLine(to: pt) }
                ctx.stroke(p, with: .color(color), lineWidth: 1.5)
            }
        }
        .allowsHitTesting(false)
    }
}

struct StaleChip: View {
    var body: some View {
        Text("STALE")
            .font(HUDFont.mono(7, weight: .medium))
            .foregroundStyle(Color.hudGold)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(Color.hudGold.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// Mini gauge: 36 ticks, track ring, gold checking arc, red card arc
struct MiniGauge: View {
    var checking: Double
    var cardOwed: Double
    var checkingMax: Double = 5000
    var cardMax: Double = 2000

    private var checkingRatio: CGFloat { CGFloat(min(checking / checkingMax, 1.0)) }
    private var cardRatio: CGFloat     { CGFloat(min(cardOwed   / cardMax,   1.0)) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let tickR = side * 0.43

            ZStack {
                // Track ring
                Circle()
                    .stroke(Color.faint.opacity(0.6), lineWidth: 1)
                    .frame(width: side * 0.84, height: side * 0.84)

                // 36 ticks at 10° intervals; every 6th is longer
                ForEach(0..<36, id: \.self) { i in
                    let long = i % 6 == 0
                    Rectangle()
                        .fill(Color.cyanDim)
                        .frame(width: long ? 1.5 : 1, height: long ? 6 : 4)
                        .offset(y: -tickR)
                        .rotationEffect(.degrees(Double(i) * 10))
                }

                // Gold checking arc (outer ring)
                Circle()
                    .trim(from: 0, to: checkingRatio)
                    .stroke(Color.hudGold, style: StrokeStyle(lineWidth: side * 0.055, lineCap: .round))
                    .frame(width: side * 0.72, height: side * 0.72)
                    .rotationEffect(.degrees(-90))

                // Red card arc (inner ring)
                Circle()
                    .trim(from: 0, to: cardRatio)
                    .stroke(Color.hudRed, style: StrokeStyle(lineWidth: side * 0.04, lineCap: .round))
                    .frame(width: side * 0.56, height: side * 0.56)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Home screen widget views

struct SmallWidgetView: View {
    let entry: HUDEntry
    private var data: WidgetData? { entry.data }
    private var threat: ThreatLevel { data?.threatLevel ?? .allClear }

    var body: some View {
        ZStack {
            VStack(spacing: 3) {
                MiniGauge(checking: data?.checking ?? 0, cardOwed: data?.cardOwed ?? 0)
                    .frame(width: 80, height: 80)

                Text(data.map { hudCurrency($0.checking, cents: entry.config.showDollarCents) } ?? "—")
                    .font(HUDFont.display(14))
                    .foregroundStyle(Color.hudGold)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 3) {
                    Image(systemName: threat.systemIcon)
                        .font(.system(size: 8))
                    Text(threat.rawValue)
                        .font(HUDFont.mono(8))
                }
                .foregroundStyle(threat.color)

                if data?.isStale == true { StaleChip() }
            }
            .padding(10)

            WidgetCornerBrackets(color: threat.color)
        }
        .widgetURL(URL(string: "morninghud://funds"))
    }
}

struct MediumWidgetView: View {
    let entry: HUDEntry
    private var data: WidgetData? { entry.data }
    private var threat: ThreatLevel { data?.threatLevel ?? .allClear }

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                // Left: gauge + amounts
                VStack(alignment: .leading, spacing: 4) {
                    MiniGauge(checking: data?.checking ?? 0, cardOwed: data?.cardOwed ?? 0)
                        .frame(width: 68, height: 68)

                    Text(data.map { hudCurrency($0.checking, cents: entry.config.showDollarCents) } ?? "—")
                        .font(HUDFont.display(13))
                        .foregroundStyle(Color.hudGold)

                    Text(data.map { "-" + hudCurrency($0.cardOwed, cents: entry.config.showDollarCents) } ?? "—")
                        .font(HUDFont.mono(11))
                        .foregroundStyle(Color.hudRed)

                    if data?.isStale == true { StaleChip() }
                }

                Rectangle()
                    .fill(Color.faint.opacity(0.5))
                    .frame(width: 1)

                // Right: lead or headline depending on focus
                VStack(alignment: .leading, spacing: 4) {
                    if entry.config.focus == .leadsFirst, let title = data?.topLeadTitle {
                        Text("TOP LEAD")
                            .font(HUDFont.mono(7))
                            .foregroundStyle(Color.dim)
                        Text(title)
                            .font(HUDFont.mono(11, weight: .medium))
                            .foregroundStyle(Color.hudText)
                            .lineLimit(2)
                        if let pay = data?.topLeadPayText {
                            Text(pay)
                                .font(HUDFont.display(12))
                                .foregroundStyle(Color.hudGold)
                        }
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: threat.systemIcon)
                                .font(.system(size: 8))
                                .foregroundStyle(threat.color)
                            Text("BRIEF")
                                .font(HUDFont.mono(7))
                                .foregroundStyle(Color.dim)
                        }
                        Text(data?.headline ?? "Morning HUD")
                            .font(HUDFont.mono(11))
                            .foregroundStyle(Color.hudText)
                            .lineLimit(3)
                    }

                    Spacer(minLength: 0)

                    if let label = data?.freshnessLabel {
                        Text(label)
                            .font(HUDFont.mono(8))
                            .foregroundStyle(Color.dim)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)

            WidgetCornerBrackets(color: threat.color)
        }
        .widgetURL(URL(string: "morninghud://home"))
    }
}

struct LargeWidgetView: View {
    let entry: HUDEntry
    private var data: WidgetData? { entry.data }
    private var threat: ThreatLevel { data?.threatLevel ?? .allClear }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                // Funds block
                HStack(spacing: 14) {
                    MiniGauge(checking: data?.checking ?? 0, cardOwed: data?.cardOwed ?? 0)
                        .frame(width: 96, height: 96)

                    VStack(alignment: .leading, spacing: 7) {
                        amountBlock(label: "CHECKING",  value: data?.checking,  color: .hudGold)
                        amountBlock(label: "CARD OWED", value: data?.cardOwed,  color: .hudRed)

                        HStack(spacing: 3) {
                            Image(systemName: threat.systemIcon)
                                .font(.system(size: 9))
                            Text(threat.rawValue)
                                .font(HUDFont.mono(9, weight: .medium))
                        }
                        .foregroundStyle(threat.color)
                    }
                }

                Rectangle()
                    .fill(Color.faint.opacity(0.5))
                    .frame(height: 1)

                // Headline / brief
                Text(data?.headline ?? "No data loaded yet.")
                    .font(HUDFont.mono(12))
                    .foregroundStyle(Color.hudText)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                // Footer: freshness + stale + refresh
                HStack(spacing: 6) {
                    if let label = data?.freshnessLabel {
                        Text(label)
                            .font(HUDFont.mono(9))
                            .foregroundStyle(Color.dim)
                    }
                    if data?.isStale == true { StaleChip() }

                    Spacer()

                    Button(intent: RefreshSnapshotIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cyanDim)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)

            WidgetCornerBrackets(color: threat.color)
        }
        .widgetURL(URL(string: "morninghud://home"))
    }

    @ViewBuilder
    private func amountBlock(label: String, value: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(HUDFont.mono(7))
                .foregroundStyle(Color.dim)
            Text(value.map { hudCurrency($0, cents: entry.config.showDollarCents) } ?? "—")
                .font(HUDFont.display(14))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Lock Screen (accessory) widget views

struct AccessoryCircularView: View {
    let entry: HUDEntry

    var body: some View {
        ZStack {
            MiniGauge(checking: entry.data?.checking ?? 0,
                      cardOwed: entry.data?.cardOwed ?? 0)

            Text(entry.data.map { hudCurrency($0.checking, cents: false) } ?? "—")
                .font(HUDFont.display(9))
                .foregroundStyle(Color.hudGold)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
        }
        .widgetAccentable()
    }
}

struct AccessoryRectangularView: View {
    let entry: HUDEntry
    private var threat: ThreatLevel { entry.data?.threatLevel ?? .allClear }

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: threat.systemIcon)
                .font(.system(size: 14))
                .foregroundStyle(threat.color)
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.data?.headline ?? "Morning HUD")
                    .font(HUDFont.mono(11))
                    .lineLimit(2)

                if let label = entry.data?.freshnessLabel {
                    Text(label)
                        .font(HUDFont.mono(8))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AccessoryInlineView: View {
    let entry: HUDEntry
    private var threat: ThreatLevel { entry.data?.threatLevel ?? .allClear }

    var body: some View {
        Label {
            Text(entry.data?.headline ?? "Morning HUD")
                .lineLimit(1)
        } icon: {
            Image(systemName: threat.systemIcon)
        }
        .widgetAccentable()
    }
}

// MARK: - Entry view routers

struct MorningHUDWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: HUDEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        case .systemLarge:  LargeWidgetView(entry: entry)
        default:            SmallWidgetView(entry: entry)
        }
    }
}

struct MorningHUDAccessoryWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: HUDEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    AccessoryCircularView(entry: entry)
        case .accessoryRectangular: AccessoryRectangularView(entry: entry)
        case .accessoryInline:      AccessoryInlineView(entry: entry)
        default:                    AccessoryCircularView(entry: entry)
        }
    }
}

// MARK: - Widget declarations

private func hudWidgetBackground(_ threat: ThreatLevel) -> some View {
    ZStack {
        Color.void
        RadialGradient(
            colors: [threat.color.opacity(0.07), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 130
        )
    }
}

struct MorningHUDWidget: Widget {
    let kind = "MorningHUD"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: HUDWidgetConfig.self, provider: HUDProvider()) { entry in
            MorningHUDWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    hudWidgetBackground(entry.data?.threatLevel ?? .allClear)
                }
        }
        .configurationDisplayName("Morning HUD")
        .description("Your personal financial dashboard.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct MorningHUDAccessoryWidget: Widget {
    let kind = "MorningHUDAccessory"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: HUDWidgetConfig.self, provider: HUDProvider()) { entry in
            MorningHUDAccessoryWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Morning HUD")
        .description("Lock Screen HUD at a glance.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Previews

#Preview("HUD Small", as: .systemSmall) {
    MorningHUDWidget()
} timeline: {
    HUDEntry(date: .now, data: WidgetData.preview, config: HUDWidgetConfig())
    HUDEntry(date: .now, data: nil,                config: HUDWidgetConfig())
}

#Preview("HUD Medium", as: .systemMedium) {
    MorningHUDWidget()
} timeline: {
    HUDEntry(date: .now, data: WidgetData.preview, config: HUDWidgetConfig())
}

#Preview("HUD Large", as: .systemLarge) {
    MorningHUDWidget()
} timeline: {
    HUDEntry(date: .now, data: WidgetData.preview, config: HUDWidgetConfig())
}

#Preview("HUD Circular", as: .accessoryCircular) {
    MorningHUDAccessoryWidget()
} timeline: {
    HUDEntry(date: .now, data: WidgetData.preview, config: HUDWidgetConfig())
}

#Preview("HUD Rectangular", as: .accessoryRectangular) {
    MorningHUDAccessoryWidget()
} timeline: {
    HUDEntry(date: .now, data: WidgetData.preview, config: HUDWidgetConfig())
}

#Preview("HUD Inline", as: .accessoryInline) {
    MorningHUDAccessoryWidget()
} timeline: {
    HUDEntry(date: .now, data: WidgetData.preview, config: HUDWidgetConfig())
}
