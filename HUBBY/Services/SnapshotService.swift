import Foundation

protocol SnapshotService: Sendable {
    func fetch() async throws -> HUDSnapshot
}

// MARK: - Mock (sample data matching the v1 contract)

final class MockSnapshotService: SnapshotService {
    func fetch() async throws -> HUDSnapshot {
        try await Task.sleep(nanoseconds: 700_000_000)
        var snap = HUDSnapshot()
        snap.schema = HUDSnapshot.requiredSchema
        snap.generatedAt = Calendar.current.date(bySettingHour: 6, minute: 6, second: 0, of: Date()) ?? Date()
        snap.threatLevel = .clear
        snap.headline = "Nothing new worth flagging."
        snap.funds = SnapshotFunds(
            checking: 609.95, cardOwed: 296.81, netWorth: 313.14, lowThreshold: 100,
            currentMonth: SnapshotMonth(label: "October 1–2, 2026", income: 12832, spending: 12303, net: 529),
            lastMonth: SnapshotMonth(label: "September 2026", income: 1408, spending: 2752.8, net: -1344.8),
            topCategories: [
                SnapshotCategory(category: "Transfers and card payments", amount: 12000, percent: 97.5),
                SnapshotCategory(category: "Food & Dining", amount: 210, percent: 1.7),
                SnapshotCategory(category: "Shopping", amount: 93, percent: 0.8),
            ]
        )
        snap.alerts = [
            SnapshotAlert(id: "1a0f8a44", severity: .warning, label: "Security alert",
                          subject: "Critical security alert", sender: "accounts.google.com",
                          receivedAt: Date().addingTimeInterval(-3600),
                          snippet: "A new sign-in to your Google Account was detected.",
                          url: "https://mail.google.com/mail/#all/thread-f:1a0f8a44"),
            SnapshotAlert(id: "1a0f8a45", severity: .info, label: "Payment",
                          subject: "Payment Received – Capital One",
                          sender: "no-reply@capitalone.com",
                          receivedAt: Date().addingTimeInterval(-172800),
                          snippet: "Your payment of $200 has been received.",
                          url: "https://mail.google.com/mail/#all/thread-f:1a0f8a45"),
        ]
        snap.leads = [
            SnapshotLead(id: "1a0f8b31:1", source: "Indeed",
                         title: "Cross Country Assistant Coaches",
                         role: "@ San Francisco University High School",
                         payText: "$5,000–$8,000 / mo",
                         total: 8000, hourly: 46.24,
                         ageRange: nil, location: "San Francisco, CA",
                         kind: "Seasonal · Part-time", posted: "1d ago",
                         url: "https://mail.google.com/mail/#all/thread-f:1a0f8b31"),
            SnapshotLead(id: "1a0f8b32:1", source: "Backstage",
                         title: "Social Media Scripted Comedy Video",
                         role: "Comedic Gen Z / Young Millennial Lead",
                         payText: "$400 / 1 day",
                         total: 400, hourly: 50,
                         ageRange: "20-30", location: "Nationwide",
                         kind: "Online Commercial · Nonunion", posted: "1d 13h ago",
                         url: "https://mail.google.com/mail/#all/thread-f:1a0f8b32"),
        ]
        snap.diagnostics = ["SAMPLE DATA — connect a live feed in Settings to see real data."]
        return snap
    }
}

// MARK: - Remote (fetches from a URL stored in Keychain)

final class RemoteSnapshotService: SnapshotService {
    private let feedURL: String
    private let feedToken: String
    private let etagKey = "snapshot_etag"

    init(feedURL: String, feedToken: String) {
        self.feedURL = feedURL
        self.feedToken = feedToken
    }

    func fetch() async throws -> HUDSnapshot {
        guard let url = URL(string: feedURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        if !feedToken.isEmpty {
            request.setValue("Bearer \(feedToken)", forHTTPHeaderField: "Authorization")
        }
        if let etag = UserDefaults.standard.string(forKey: etagKey) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }

        switch http.statusCode {
        case 304:
            throw SnapshotError.notModified
        case 401, 403:
            throw ServiceError.unauthorized
        case 200:
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                UserDefaults.standard.set(etag, forKey: etagKey)
            }
            let snap = try HUDSnapshot.decoder.decode(HUDSnapshot.self, from: data)
            guard snap.isValid else {
                throw SnapshotError.schemaMismatch(received: snap.schema ?? "unknown")
            }
            return snap
        default:
            throw SnapshotError.feedError(http.statusCode)
        }
    }
}
