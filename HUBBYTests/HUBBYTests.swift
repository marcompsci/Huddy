import Testing
import Foundation
@testable import HUBBY

// MARK: - Snapshot decoding tests

@Suite("Snapshot Decoding")
struct SnapshotDecodingTests {

    let sampleJSON = """
    {
      "schema": "morninghud.v1",
      "generated_at": "2026-10-02T13:06:40Z",
      "threat_level": "clear",
      "headline": "Nothing new worth flagging.",
      "funds": {
        "checking": 609.95,
        "card_owed": 296.81,
        "net_worth": 313.14,
        "low_threshold": 100,
        "current_month": {"label": "October 1–2, 2026", "income": 12832.0, "spending": 12303.0, "net": 529.0},
        "last_month": {"label": "September 2026", "income": 1408.0, "spending": 2752.8, "net": -1344.8},
        "top_categories": [
          {"category": "Transfers and card payments", "amount": 12000.0, "percent": 97.5}
        ]
      },
      "alerts": [
        {"id": "1a0f8a44", "severity": "warning", "label": "Security alert",
         "subject": "Critical security alert", "sender": "accounts.google.com",
         "received_at": "2026-10-01T18:05:05Z", "snippet": "...",
         "url": "https://mail.google.com/mail/?#all/thread-f:1a0f8a44"}
      ],
      "leads": [
        {"id": "1a0f8b31:1", "source": "Indeed", "title": "Cross Country Assistant Coaches",
         "role": "@ San Francisco University High School", "pay_text": "$5,000–$8,000 / mo",
         "total": 8000, "hourly": 46.24, "age_range": null, "location": "San Francisco, CA",
         "kind": "Seasonal · Part-time", "posted": "1d ago",
         "url": "https://mail.google.com/mail/?#all/thread-f:1a0f8b31"}
      ],
      "diagnostics": ["Data from Chase Bank may be incomplete."]
    }
    """

    @Test("Full sample decodes correctly")
    func testFullSampleDecoding() throws {
        let data = Data(sampleJSON.utf8)
        let snap = try HUDSnapshot.decoder.decode(HUDSnapshot.self, from: data)

        #expect(snap.isValid)
        #expect(snap.schema == "morninghud.v1")
        #expect(snap.headline == "Nothing new worth flagging.")
        #expect(snap.threatLevel == .clear)
        #expect(snap.resolvedThreatLevel == .allClear)

        let funds = try #require(snap.funds)
        #expect(funds.checking == 609.95)
        #expect(funds.cardOwed == 296.81)
        #expect(funds.netWorth == 313.14)
        #expect(funds.lowThreshold == 100)
        #expect(funds.currentMonth?.income == 12832.0)
        #expect(funds.lastMonth?.net == -1344.8)
        #expect(funds.topCategories?.first?.category == "Transfers and card payments")
        #expect(funds.topCategories?.first?.amount == 12000.0)
        #expect(funds.topCategories?.first?.percent == 97.5)

        let alert = try #require(snap.alerts?.first)
        #expect(alert.id == "1a0f8a44")
        #expect(alert.severity == .warning)
        #expect(alert.resolvedSeverity == .warning)
        #expect(alert.label == "Security alert")

        let lead = try #require(snap.leads?.first)
        #expect(lead.id == "1a0f8b31:1")
        #expect(lead.source == "Indeed")
        #expect(lead.payText == "$5,000–$8,000 / mo")
        #expect(lead.total == 8000)
        #expect(lead.hourly == 46.24)
        #expect(lead.location == "San Francisco, CA")

        #expect(snap.diagnostics?.first == "Data from Chase Bank may be incomplete.")
    }

    @Test("Payload with missing optional fields does not crash")
    func testMissingOptionalFields() throws {
        let minimal = """
        {"schema": "morninghud.v1", "generated_at": "2026-10-02T06:00:00Z",
         "threat_level": "clear", "headline": "OK"}
        """
        let snap = try HUDSnapshot.decoder.decode(HUDSnapshot.self, from: Data(minimal.utf8))
        #expect(snap.isValid)
        #expect(snap.funds == nil)
        #expect(snap.alerts == nil)
        #expect(snap.leads == nil)
        #expect(snap.diagnostics == nil)
        #expect(snap.resolvedThreatLevel == .allClear)
    }

    @Test("Wrong schema is detected as invalid")
    func testWrongSchema() throws {
        let bad = """
        {"schema": "someother.v2", "generated_at": "2026-10-02T06:00:00Z",
         "threat_level": "clear", "headline": "Bad"}
        """
        let snap = try HUDSnapshot.decoder.decode(HUDSnapshot.self, from: Data(bad.utf8))
        #expect(!snap.isValid)
        #expect(snap.schema == "someother.v2")
    }
}

// MARK: - Staleness tests

@Suite("Staleness Logic")
struct StalenessTests {

    @Test("25-hour-old snapshot is NOT stale")
    func testNotStaleAt25Hours() {
        let gen = Date().addingTimeInterval(-(25 * 3600))
        #expect(!NotificationLogic.isStale(gen))
    }

    @Test("27-hour-old snapshot IS stale")
    func testStaleAt27Hours() {
        let gen = Date().addingTimeInterval(-(27 * 3600))
        #expect(NotificationLogic.isStale(gen))
    }

    @Test("nil generatedAt is always stale")
    func testNilIsStale() {
        #expect(NotificationLogic.isStale(nil))
    }
}

// MARK: - Notification logic tests

@Suite("Notification Logic")
struct NotificationLogicTests {

    @Test("Should notify when no previous notification")
    func testShouldNotifyWithNoPrevious() {
        let gen = Date()
        #expect(NotificationLogic.shouldNotify(newGeneratedAt: gen, lastNotifiedAt: nil))
    }

    @Test("Should notify when new snapshot is newer")
    func testShouldNotifyWhenNewer() {
        let old = Date().addingTimeInterval(-3600)
        let new = Date()
        #expect(NotificationLogic.shouldNotify(newGeneratedAt: new, lastNotifiedAt: old))
    }

    @Test("Should NOT notify when snapshot is same or older")
    func testShouldNotNotifyWhenSameOrOlder() {
        let t = Date()
        #expect(!NotificationLogic.shouldNotify(newGeneratedAt: t, lastNotifiedAt: t))
        let earlier = t.addingTimeInterval(-60)
        #expect(!NotificationLogic.shouldNotify(newGeneratedAt: earlier, lastNotifiedAt: t))
    }

    @Test("Should NOT notify when generatedAt is nil")
    func testShouldNotNotifyWhenNilGenerated() {
        #expect(!NotificationLogic.shouldNotify(newGeneratedAt: nil, lastNotifiedAt: nil))
    }

    @Test("Notification content for ALERT with 1 critical item")
    func testAlertContent() throws {
        var snap = HUDSnapshot()
        snap.schema = "morninghud.v1"
        snap.threatLevel = .alert
        snap.headline = "1 critical item flagged."
        snap.alerts = [
            SnapshotAlert(id: "x", severity: .critical, label: "New sign-in",
                          subject: "Critical security alert", sender: "google.com",
                          receivedAt: Date(), snippet: "…", url: nil)
        ]
        snap.leads = [
            SnapshotLead(id: "y", source: "Indeed", title: "Coach",
                         payText: "$8,000 / mo", total: 8000, hourly: 46)
        ]
        let (title, body) = NotificationLogic.content(for: snap)
        #expect(title == "ALERT · 1 security item")
        #expect(body.contains("Top lead $8,000 / mo"))
    }

    @Test("Notification content for ALL CLEAR with no leads")
    func testAllClearContent() {
        var snap = HUDSnapshot()
        snap.schema = "morninghud.v1"
        snap.threatLevel = .clear
        snap.headline = "Nothing new worth flagging."
        let (title, body) = NotificationLogic.content(for: snap)
        #expect(title == "ALL CLEAR")
        #expect(body == "Nothing new worth flagging.")
    }
}
