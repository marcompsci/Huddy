import Foundation

enum NotificationLogic {

    // Returns true when the new snapshot's generatedAt is strictly after the last notified timestamp.
    static func shouldNotify(newGeneratedAt: Date?, lastNotifiedAt: Date?) -> Bool {
        guard let new = newGeneratedAt else { return false }
        guard let last = lastNotifiedAt else { return true }
        return new > last
    }

    // Builds the notification title and body strings from a snapshot.
    static func content(for snapshot: HUDSnapshot) -> (title: String, body: String) {
        let level = snapshot.resolvedThreatLevel
        let criticalCount = (snapshot.alerts ?? []).filter { $0.severity == .critical }.count

        var title: String
        switch level {
        case .alert:
            title = criticalCount > 0 ? "ALERT · \(criticalCount) security item\(criticalCount == 1 ? "" : "s")" : "ALERT"
        case .watch:
            title = "WATCH"
        case .allClear:
            title = "ALL CLEAR"
        }

        var body = snapshot.headline ?? ""
        if let lead = snapshot.leads?.max(by: { ($0.hourly ?? 0) < ($1.hourly ?? 0) }),
           let payText = lead.payText {
            body += " · Top lead \(payText)"
        }

        return (title, body)
    }

    // Staleness: snapshot is considered stale if generatedAt is more than 26 hours ago.
    static func isStale(_ generatedAt: Date?, referenceDate: Date = Date()) -> Bool {
        guard let gen = generatedAt else { return true }
        return referenceDate.timeIntervalSince(gen) > 93_600 // 26 * 3600
    }
}
