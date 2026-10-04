import Testing
import Foundation
@testable import HUBBY

// MARK: - VegaState tests

@Suite("VegaState")
struct VegaStateTests {

    @Test("Equatable: same cases are equal")
    func testEquality() {
        #expect(VegaState.idle        == .idle)
        #expect(VegaState.thinking    == .thinking)
        #expect(VegaState.alert       == .alert)
        #expect(VegaState.listening(level: 0.5) == .listening(level: 0.5))
        #expect(VegaState.speaking(amplitude: 0.3) == .speaking(amplitude: 0.3))
    }

    @Test("Equatable: different levels are not equal")
    func testDifferentLevels() {
        #expect(VegaState.listening(level: 0.2) != .listening(level: 0.8))
        #expect(VegaState.speaking(amplitude: 0.1) != .speaking(amplitude: 0.9))
    }

    @Test("primaryColor differs by state")
    func testPrimaryColor() {
        #expect(VegaState.idle.primaryColor   == VegaState.thinking.primaryColor)  // both cyan
        #expect(VegaState.alert.primaryColor  != VegaState.idle.primaryColor)       // red vs cyan
        #expect(VegaState.speaking(amplitude: 0).primaryColor != VegaState.idle.primaryColor) // gold vs cyan
    }

    @Test("Convenience booleans")
    func testBooleans() {
        #expect(VegaState.listening(level: 0).isListening)
        #expect(!VegaState.idle.isListening)
        #expect(VegaState.thinking.isThinking)
        #expect(!VegaState.idle.isThinking)
        #expect(VegaState.speaking(amplitude: 0.5).isSpeaking)
        #expect(!VegaState.idle.isSpeaking)
        #expect(VegaState.alert.isAlert)
        #expect(!VegaState.idle.isAlert)
    }

    @Test("pillLabel strings are non-empty and uppercase")
    func testPillLabels() {
        let states: [VegaState] = [.idle, .listening(level: 0), .thinking, .speaking(amplitude: 0), .alert]
        for state in states {
            let label = state.pillLabel
            #expect(!label.isEmpty)
            #expect(label == label.uppercased())
        }
    }
}

// MARK: - MockAssistantBackend script selection tests

@Suite("MockAssistantBackend")
struct MockBackendTests {

    @Test("Balance query returns events within timeout")
    func testBalanceStreamCompletesQuickly() async throws {
        let backend = MockAssistantBackend()
        let stream  = backend.stream(userText: "what's my balance", history: [], snapshot: nil)

        var gotDone = false
        var textSeen = ""
        var cardSeen = false

        for try await event in stream {
            switch event {
            case .textDelta(let t): textSeen += t
            case .card(let c):
                if case .balance = c { cardSeen = true }
            case .done: gotDone = true
            default: break
            }
        }

        #expect(gotDone)
        #expect(cardSeen)
        #expect(!textSeen.isEmpty)
    }

    @Test("Alert query returns alertList card")
    func testAlertStreamHasCard() async throws {
        let backend = MockAssistantBackend()
        var foundAlert = false

        for try await event in backend.stream(userText: "any alerts", history: [], snapshot: nil) {
            if case .card(let c) = event, case .alertList = c { foundAlert = true }
        }

        #expect(foundAlert)
    }

    @Test("Lead query returns leadList card")
    func testLeadStreamHasCard() async throws {
        let backend = MockAssistantBackend()
        var foundLead = false

        for try await event in backend.stream(userText: "top job lead", history: [], snapshot: nil) {
            if case .card(let c) = event, case .leadList = c { foundLead = true }
        }

        #expect(foundLead)
    }

    @Test("General query still completes")
    func testGeneralQueryCompletes() async throws {
        let backend = MockAssistantBackend()
        var done = false

        for try await event in backend.stream(userText: "hello", history: [], snapshot: nil) {
            if case .done = event { done = true }
        }

        #expect(done)
    }

    @Test("Snapshot values reach the card")
    func testSnapshotValuesInCard() async throws {
        let snap = SnapshotPayload(checking: 9999.0, cardOwed: 111.0,
                                   headline: "Test", threat: "ALERT",
                                   leads: [], alerts: [])
        let backend = MockAssistantBackend()
        var checkingFound = false

        for try await event in backend.stream(userText: "balance", history: [], snapshot: snap) {
            if case .card(let c) = event,
               case let .balance(checking, _, _, _) = c,
               checking == 9999.0 {
                checkingFound = true
            }
        }

        #expect(checkingFound)
    }
}

// MARK: - VegaSession persistence tests

@Suite("VegaSession")
struct VegaSessionTests {

    @Test("Appended turns are visible immediately")
    func testAppend() {
        let session = VegaSession.shared
        let before  = session.turns.count
        session.append(VegaTurn(role: .user, text: "hello"))
        #expect(session.turns.count == before + 1)
        #expect(session.turns.last?.text == "hello")
    }

    @Test("updateLast modifies the last turn")
    func testUpdateLast() {
        let session = VegaSession.shared
        session.append(VegaTurn(role: .assistant, text: "partial"))
        session.updateLast(text: "final")
        #expect(session.turns.last?.text == "final")
    }

    @Test("historyForBackend maps roles correctly")
    func testHistoryForBackend() {
        let session = VegaSession.shared
        session.clear()
        session.append(VegaTurn(role: .user, text: "Q"))
        session.append(VegaTurn(role: .assistant, text: "A"))
        let history = session.historyForBackend
        #expect(history.count == 2)
        #expect(history[0]["role"] == "user")
        #expect(history[1]["role"] == "assistant")
    }
}

// MARK: - AssistantCard Codable round-trip

@Suite("AssistantCard Codable")
struct AssistantCardCodableTests {

    @Test("Balance card round-trips through JSON")
    func testBalanceRoundTrip() throws {
        let card: AssistantCard = .balance(checking: 1234.56, cardOwed: 78.90,
                                           source: "Test", age: "1m ago")
        let data    = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(AssistantCard.self, from: data)
        #expect(card == decoded)
    }

    @Test("alertList round-trips through JSON")
    func testAlertListRoundTrip() throws {
        let card: AssistantCard = .alertList(items: ["Item A", "Item B"], level: "ALERT", source: "Snap")
        let data    = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(AssistantCard.self, from: data)
        #expect(card == decoded)
    }
}

// MARK: - SnapshotPayload tests

@Suite("SnapshotPayload")
struct SnapshotPayloadTests {

    @Test("Direct init stores all fields")
    func testDirectInit() {
        let snap = SnapshotPayload(
            checking: 5_000.0,
            cardOwed: 250.0,
            headline: "Test headline",
            threat:   "WATCH",
            leads:    ["Lead A", "Lead B"],
            alerts:   ["Alert X"]
        )
        #expect(snap.checking == 5_000.0)
        #expect(snap.cardOwed == 250.0)
        #expect(snap.headline == "Test headline")
        #expect(snap.threat   == "WATCH")
        #expect(snap.leads    == ["Lead A", "Lead B"])
        #expect(snap.alerts   == ["Alert X"])
    }

    @Test("Encodes to JSON with expected keys")
    func testJSONEncoding() throws {
        let snap = SnapshotPayload(
            checking: 1_234.0,
            cardOwed: 56.0,
            headline: "Hello",
            threat:   "ALL_CLEAR",
            leads:    ["L1"],
            alerts:   []
        )
        let data = try JSONEncoder().encode(snap)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["checking"] as? Double == 1_234.0)
        #expect(json["headline"] as? String == "Hello")
        #expect(json["threat"]   as? String == "ALL_CLEAR")
    }

    @Test("Round-trips through JSON without data loss")
    func testJSONRoundTrip() throws {
        let snap = SnapshotPayload(
            checking: 9_876.54,
            cardOwed: 321.0,
            headline: "Round-trip",
            threat:   "ALERT",
            leads:    ["A", "B"],
            alerts:   ["X"]
        )
        let data    = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(SnapshotPayload.self, from: data)
        #expect(decoded.checking == snap.checking)
        #expect(decoded.cardOwed == snap.cardOwed)
        #expect(decoded.headline == snap.headline)
        #expect(decoded.threat   == snap.threat)
        #expect(decoded.leads    == snap.leads)
        #expect(decoded.alerts   == snap.alerts)
    }
}

// MARK: - AssistantClient tool-status callback tests

@Suite("AssistantClient")
@MainActor
struct AssistantClientTests {

    @Test("onToolStatus receives nil when mock stream completes")
    func testToolStatusClearedOnDone() async throws {
        let client   = AssistantClient(backend: MockAssistantBackend())
        var statuses = [String?]()
        var isDone   = false

        client.send(
            userText:     "balance",
            snapshot:     nil,
            onState:      { state in if state == .idle { isDone = true } },
            onToolStatus: { msg in statuses.append(msg) },
            onSpeak:      { _ in }
        )

        // MockAssistantBackend finishes quickly; poll up to 3 s
        for _ in 0..<30 {
            if isDone { break }
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(isDone, "stream did not complete within 3 s")
        // The .done branch always calls onToolStatus(nil) — must appear in collected calls
        #expect(statuses.contains(where: { $0 == nil }), "onToolStatus(nil) was never called on completion")
    }
}

// MARK: - VegaAccountManager sign-in state tests

@Suite("VegaAccountManager")
@MainActor
struct VegaAccountManagerTests {

    @Test("isSignedIn is false after signOut")
    func testIsSignedInFalseAfterSignOut() {
        VegaAccountManager.shared.signOut()
        #expect(!VegaAccountManager.shared.isSignedIn)
    }

    @Test("sessionToken is nil after signOut")
    func testSessionTokenNilAfterSignOut() {
        VegaAccountManager.shared.signOut()
        let token = VegaAccountManager.shared.sessionToken
        #expect(token == nil || token?.isEmpty == true)
    }
}
