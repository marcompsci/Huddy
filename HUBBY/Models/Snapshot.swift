import Foundation

// MARK: - Top-level snapshot (morninghud.v1)

struct HUDSnapshot: Codable {
    var schema: String?
    var generatedAt: Date?
    var threatLevel: SnapshotThreatLevel?
    var headline: String?
    var funds: SnapshotFunds?
    var alerts: [SnapshotAlert]?
    var leads: [SnapshotLead]?
    var diagnostics: [String]?

    static let requiredSchema = "morninghud.v1"
    var isValid: Bool { schema == Self.requiredSchema }

    var resolvedThreatLevel: ThreatLevel {
        switch threatLevel {
        case .alert: return .alert
        case .watch: return .watch
        default: return .allClear
        }
    }

    // More than 26 hours since generatedAt
    var isStale: Bool {
        guard let gen = generatedAt else { return true }
        return Date().timeIntervalSince(gen) > 93_600
    }

    var freshnessLabel: String {
        guard let gen = generatedAt else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "EEE HH:mm"
        return f.string(from: gen)
    }

    // Decoder with snake_case + ISO8601 dates
    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

enum SnapshotThreatLevel: String, Codable { case clear, watch, alert }

// MARK: - Funds

struct SnapshotFunds: Codable {
    var checking: Double?
    var cardOwed: Double?
    var netWorth: Double?
    var lowThreshold: Double?
    var currentMonth: SnapshotMonth?
    var lastMonth: SnapshotMonth?
    var topCategories: [SnapshotCategory]?
}

struct SnapshotMonth: Codable {
    var label: String?
    var income: Double?
    var spending: Double?
    var net: Double?
}

struct SnapshotCategory: Codable, Identifiable {
    var id: String { category ?? UUID().uuidString }
    var category: String?
    var amount: Double?
    var percent: Double?
}

// MARK: - Alerts

struct SnapshotAlert: Codable, Identifiable {
    var id: String?
    var severity: SnapshotSeverity?
    var label: String?
    var subject: String?
    var sender: String?
    var receivedAt: Date?
    var snippet: String?
    var url: String?

    var resolvedSeverity: Severity {
        switch severity {
        case .critical: return .critical
        case .warning: return .warning
        default: return .info
        }
    }
}

enum SnapshotSeverity: String, Codable { case critical, warning, info }

// MARK: - Leads

struct SnapshotLead: Codable, Identifiable {
    var id: String?
    var source: String?
    var title: String?
    var role: String?
    var payText: String?
    var total: Double?
    var hourly: Double?
    var ageRange: String?
    var location: String?
    var kind: String?
    var posted: String?
    var url: String?
}

// MARK: - ThreatLevel (shared between snapshot and DashboardStore)

enum ThreatLevel: String, Codable {
    case alert = "ALERT"
    case watch = "WATCH"
    case allClear = "ALL CLEAR"
}

// MARK: - Widget shared data (written to App Group Snapshot.json)

struct WidgetData: Codable {
    var checking: Double
    var cardOwed: Double
    var threatLevel: ThreatLevel
    var headline: String
    var topLeadPayText: String?
    var topLeadTitle: String?
    var generatedAt: Date
}

// MARK: - Snapshot errors

enum SnapshotError: LocalizedError {
    case schemaMismatch(received: String)
    case notModified
    case noCache
    case feedError(Int)

    var errorDescription: String? {
        switch self {
        case .schemaMismatch(let s): return "Feed format changed (got \"\(s)\")"
        case .notModified: return "No change"
        case .noCache: return "No cached data"
        case .feedError(let code): return "Feed returned HTTP \(code)"
        }
    }
}
