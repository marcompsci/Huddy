import AppIntents

// MARK: - Individual Siri shortcuts

struct AskVegaIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask VEGA"
    static let description = IntentDescription("Open VEGA and start a conversation.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}

struct VegaMorningBriefIntent: AppIntent {
    static let title: LocalizedStringResource = "VEGA Morning Brief"
    static let description = IntentDescription("Play today's morning brief from VEGA.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}

struct VegaBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "VEGA — My Balance"
    static let description = IntentDescription("Ask VEGA what your current balance is.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}

struct VegaAlertsIntent: AppIntent {
    static let title: LocalizedStringResource = "VEGA — Any Alerts"
    static let description = IntentDescription("Ask VEGA to read your financial alerts.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}

struct VegaTopLeadIntent: AppIntent {
    static let title: LocalizedStringResource = "VEGA — Top Lead"
    static let description = IntentDescription("Ask VEGA what your top job lead is.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult { .result() }
}

// MARK: - App shortcuts provider
// Every phrase MUST contain ${applicationName} per AppIntents requirement.

struct VegaAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskVegaIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Open \(.applicationName) VEGA",
                "Talk to \(.applicationName)"
            ],
            shortTitle: "Ask VEGA",
            systemImageName: "waveform.circle.fill"
        )
        AppShortcut(
            intent: VegaMorningBriefIntent(),
            phrases: [
                "\(.applicationName) morning brief",
                "Play my morning brief in \(.applicationName)"
            ],
            shortTitle: "Morning Brief",
            systemImageName: "sun.horizon.fill"
        )
        AppShortcut(
            intent: VegaBalanceIntent(),
            phrases: [
                "\(.applicationName) what's my balance",
                "Ask \(.applicationName) my balance"
            ],
            shortTitle: "My Balance",
            systemImageName: "banknote"
        )
        AppShortcut(
            intent: VegaAlertsIntent(),
            phrases: [
                "\(.applicationName) any alerts",
                "Check my alerts with \(.applicationName)"
            ],
            shortTitle: "Any Alerts",
            systemImageName: "exclamationmark.shield"
        )
        AppShortcut(
            intent: VegaTopLeadIntent(),
            phrases: [
                "\(.applicationName) top job lead",
                "\(.applicationName) best lead"
            ],
            shortTitle: "Top Lead",
            systemImageName: "briefcase"
        )
    }
}
