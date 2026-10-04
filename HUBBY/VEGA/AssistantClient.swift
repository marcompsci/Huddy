import Foundation

// MARK: - SSE event types from /v1/assistant/chat

enum SSEEvent {
    case textDelta(String)
    case toolCall(name: String, args: [String: String])
    case toolStatus(String)
    case card(AssistantCard)
    case done
    case error(String)
}

// MARK: - Backend protocol (real or mock)

protocol AssistantBackend: AnyObject, Sendable {
    func stream(userText: String, history: [[String: String]], snapshot: SnapshotPayload?) -> AsyncThrowingStream<SSEEvent, Error>
}

// MARK: - AssistantClient: drives VegaStore via stream events

@MainActor
final class AssistantClient {

    private let backend: any AssistantBackend
    private var streamTask: Task<Void, Never>?
    private let session = VegaSession.shared

    init(backend: any AssistantBackend = MockAssistantBackend()) {
        self.backend = backend
    }

    /// Send user text, stream response into the session, call back on each state change.
    func send(
        userText:     String,
        snapshot:     SnapshotPayload?,
        onState:      @escaping (VegaState) -> Void,
        onToolStatus: @escaping (String?) -> Void = { _ in },
        onSpeak:      @escaping (String) async -> Void
    ) {
        // Persist user turn
        session.append(VegaTurn(role: .user, text: userText))

        // Placeholder assistant turn (built up incrementally)
        let assistantTurn = VegaTurn(role: .assistant, text: "")
        session.append(assistantTurn)

        streamTask?.cancel()
        streamTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var fullText     = ""
            var cards:       [AssistantCard] = []
            var firstToken   = true

            let stream = backend.stream(userText: userText, history: session.historyForBackend, snapshot: snapshot)

            do {
                for try await event in stream {
                    guard !Task.isCancelled else { break }
                    switch event {
                    case .textDelta(let delta):
                        fullText += delta
                        session.updateLast(text: fullText, cards: cards)
                        if firstToken {
                            firstToken = false
                            onState(.speaking(amplitude: 0.5))
                            await onSpeak(fullText)
                        }

                    case .card(let card):
                        cards.append(card)
                        session.updateLast(text: fullText, cards: cards)

                    case .toolStatus(let msg):
                        onToolStatus(msg)

                    case .toolCall(let name, let args):
                        await handleToolCall(name: name, args: args)

                    case .done:
                        session.updateLast(text: fullText, cards: cards)
                        onToolStatus(nil)
                        onState(.idle)

                    case .error(let msg):
                        session.updateLast(text: "Error: \(msg)", cards: cards)
                        onToolStatus(nil)
                        onState(.idle)
                    }
                }
            } catch {
                session.updateLast(text: fullText.isEmpty ? "Request failed." : fullText, cards: cards)
                onToolStatus(nil)
                onState(.idle)
            }
        }
    }

    func cancel() {
        streamTask?.cancel()
    }

    // MARK: - Client-side tool execution

    private func handleToolCall(name: String, args: [String: String]) async {
        switch name {
        case "navigate":
            if let dest = args["destination"] {
                NotificationCenter.default.post(
                    name: .vegaNavigate, object: nil, userInfo: ["destination": dest]
                )
            }
        case "set_reminder":
            guard let title = args["title"], let isoDate = args["fire_at"],
                  let date = ISO8601DateFormatter().date(from: isoDate) else { break }
            await ReminderTool.schedule(title: title, at: date)
        default:
            break
        }
    }
}

extension Notification.Name {
    static let vegaNavigate = Notification.Name("vega.navigate")
}

// MARK: - SnapshotPayload passthrough (from DashboardStore)

struct SnapshotPayload: Encodable, Sendable {
    let checking:  Double
    let cardOwed:  Double
    let headline:  String
    let threat:    String
    let leads:     [String]
    let alerts:    [String]
}

extension SnapshotPayload {
    init?(snapshot: HUDSnapshot) {
        checking = snapshot.funds?.checking ?? 0
        cardOwed = snapshot.funds?.cardOwed ?? 0
        headline = snapshot.headline ?? ""
        threat   = snapshot.resolvedThreatLevel.rawValue
        leads    = (snapshot.leads  ?? []).compactMap { $0.title }
        alerts   = (snapshot.alerts ?? []).compactMap { $0.subject ?? $0.label }
    }
}
