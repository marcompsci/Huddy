import Foundation
import UserNotifications
import UIKit

// MARK: - Schedules the 6:10 AM brief notification and handles "Play"/"Later" actions

enum VegaMorningBrief {

    static let notificationCategory = "VEGA_BRIEF"
    static let playAction            = "VEGA_BRIEF_PLAY"
    static let laterAction           = "VEGA_BRIEF_LATER"

    // MARK: - Register notification category (call once at launch)

    @MainActor
    static func registerCategory() {
        let play = UNNotificationAction(
            identifier: playAction,
            title: "Play",
            options: [.foreground]
        )
        let later = UNNotificationAction(
            identifier: laterAction,
            title: "Later",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: notificationCategory,
            actions: [play, later],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Generate brief via backend, then post notification

    /// Calls POST /v1/brief (if credentials exist), falls back to snapshot-derived text.
    @MainActor
    static func generateAndPost(snapshot: SnapshotPayload?) async {
        let text = await fetchBriefText(snapshot: snapshot)
        if let t = text, !t.isEmpty {
            await post(headline: "Morning Brief", body: t)
        } else if let snap = snapshot {
            await post(headline: "Morning Brief", body: buildFallbackText(snap))
        }
    }

    private static func fetchBriefText(snapshot: SnapshotPayload?) async -> String? {
        guard
            let rawURL = Keychain.get(Keychain.Keys.vegaBackendURL), !rawURL.isEmpty,
            let token  = Keychain.get(Keychain.Keys.vegaSessionToken), !token.isEmpty,
            !token.hasPrefix("stub_"),
            let url = URL(string: rawURL)?.appendingPathComponent("v1/brief")
        else { return nil }

        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)",  forHTTPHeaderField: "Authorization")
        if let snap = snapshot, let body = try? JSONEncoder().encode(snap) {
            req.httpBody = body
        }
        guard
            let (data, resp) = try? await URLSession.shared.data(for: req),
            let http = resp as? HTTPURLResponse, http.statusCode == 200,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let text = json["text"] as? String
        else { return nil }
        return text
    }

    private static func buildFallbackText(_ snap: SnapshotPayload) -> String {
        var parts: [String] = []
        if !snap.headline.isEmpty { parts.append(snap.headline) }
        if snap.checking > 0 {
            let amt = snap.checking >= 1000
                ? String(format: "$%.0fK", snap.checking / 1000)
                : String(format: "$%.0f",  snap.checking)
            parts.append("Checking \(amt)")
        }
        if !snap.alerts.isEmpty {
            parts.append("\(snap.alerts.count) alert\(snap.alerts.count == 1 ? "" : "s")")
        }
        if !snap.leads.isEmpty {
            parts.append("\(snap.leads.count) lead\(snap.leads.count == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "Your morning brief is ready." : parts.joined(separator: ". ")
    }

    // MARK: - Post brief notification

    @MainActor
    static func post(headline: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        guard (await center.notificationSettings()).authorizationStatus == .authorized else { return }

        let content                     = UNMutableNotificationContent()
        content.title                   = "VEGA Morning Brief"
        content.body                    = body
        content.sound                   = .default
        content.categoryIdentifier      = notificationCategory
        if #available(iOS 15, *) { content.interruptionLevel = .timeSensitive }

        let req = UNNotificationRequest(
            identifier: "vega.brief.\(Int(Date().timeIntervalSince1970))",
            content: content, trigger: nil
        )
        try? await center.add(req)
    }
}

// MARK: - Notification name for "Play" action deep link

extension Notification.Name {
    static let vegaBriefPlay = Notification.Name("vega.brief.play")
}

// MARK: - Sentinel: compare snapshots, alert on new critical items

@MainActor
final class VegaSentinel {

    private var lastKnownAlertIDs: Set<String> = []
    private let store: DashboardStore

    init(store: DashboardStore) {
        self.store = store
    }

    /// Call after every snapshot refresh. Returns true if a new critical alert was notified.
    @discardableResult
    func scan() async -> Bool {
        guard let snap = store.snapshot else { return false }

        let snapshotAlerts = snap.alerts ?? []
        let currentIDs     = Set(snapshotAlerts.compactMap { $0.id })
        let newIDs         = currentIDs.subtracting(lastKnownAlertIDs)
        lastKnownAlertIDs  = currentIDs

        // Update badge with critical count
        let criticalCount = snapshotAlerts.filter { $0.severity == .critical }.count
        await updateBadge(criticalCount)

        guard !newIDs.isEmpty else { return false }

        // Only alert on critical items that are new
        let newCritical = snapshotAlerts.filter {
            guard let id = $0.id else { return false }
            return newIDs.contains(id) && $0.severity == .critical
        }
        guard let first = newCritical.first else { return false }

        let center = UNUserNotificationCenter.current()
        guard (await center.notificationSettings()).authorizationStatus == .authorized else { return false }

        let content   = UNMutableNotificationContent()
        content.title = "VEGA Alert"
        content.body  = first.subject ?? first.label ?? "New critical alert"
        content.sound = .defaultCritical
        if #available(iOS 15, *) { content.interruptionLevel = .timeSensitive }

        let req = UNNotificationRequest(
            identifier: "vega.sentinel.\(first.id ?? UUID().uuidString)",
            content: content, trigger: nil
        )
        try? await center.add(req)
        return true
    }

    private func updateBadge(_ count: Int) async {
        if #available(iOS 16, *) {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }
}
