import Foundation

// MARK: - Real SSE backend — POST /v1/assistant/chat

final class LiveAssistantBackend: AssistantBackend, @unchecked Sendable {

    private let baseURL: URL
    private let token:   String

    init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token   = token
    }

    // MARK: - Factory

    /// Returns a LiveAssistantBackend if both baseURL and session token are configured,
    /// otherwise returns the MockAssistantBackend.
    static func makeOrMock() -> any AssistantBackend {
        guard
            let rawURL = Keychain.get(Keychain.Keys.vegaBackendURL),
            !rawURL.isEmpty,
            let url = URL(string: rawURL),
            let token = Keychain.get(Keychain.Keys.vegaSessionToken),
            !token.isEmpty
        else {
            return MockAssistantBackend()
        }
        return LiveAssistantBackend(baseURL: url, token: token)
    }

    // MARK: - Stream

    func stream(
        userText: String,
        history:  [[String: String]],
        snapshot: SnapshotPayload?
    ) -> AsyncThrowingStream<SSEEvent, Error> {

        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = baseURL.appendingPathComponent("v1/assistant/chat")
                    var req = URLRequest(url: url, timeoutInterval: 90)
                    req.httpMethod = "POST"
                    req.setValue("application/json",   forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream",  forHTTPHeaderField: "Accept")
                    req.setValue("Bearer \(self.token)", forHTTPHeaderField: "Authorization")

                    // Request body
                    var body: [String: Any] = [
                        "user":    userText,
                        "history": history
                    ]
                    if let snap = snapshot,
                       let snapData = try? JSONEncoder().encode(snap),
                       let snapDict = try? JSONSerialization.jsonObject(with: snapData) {
                        body["snapshot"] = snapDict
                    }
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        throw ServiceError.invalidResponse
                    }
                    if http.statusCode == 401 { throw ServiceError.unauthorized }
                    guard http.statusCode == 200 else { throw ServiceError.httpError(http.statusCode) }

                    // Read SSE line-by-line
                    var lineBuf = ""
                    for try await byte in bytes {
                        guard let ch = String(bytes: [byte], encoding: .utf8) else { continue }
                        if ch == "\n" {
                            let line = lineBuf
                            lineBuf = ""
                            guard line.hasPrefix("data: ") else { continue }
                            let payload = String(line.dropFirst(6))
                            if payload == "[DONE]" {
                                continuation.yield(.done)
                                continuation.finish()
                                return
                            }
                            if let event = Self.parseEvent(payload) {
                                continuation.yield(event)
                                if case .done = event { continuation.finish(); return }
                                if case .error = event { continuation.finish(); return }
                            }
                        } else {
                            lineBuf += ch
                        }
                    }
                    continuation.yield(.done)
                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - SSE event parser

    private static func parseEvent(_ payload: String) -> SSEEvent? {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return nil }

        switch type {
        case "text_delta":
            return (json["delta"] as? String).map { .textDelta($0) }

        case "tool_call":
            let name = json["name"] as? String ?? ""
            let raw  = json["args"] as? [String: Any] ?? [:]
            let args = raw.compactMapValues { "\($0)" }
            return .toolCall(name: name, args: args)

        case "tool_status":
            return (json["message"] as? String).map { .toolStatus($0) }

        case "card":
            return parseCard(json)

        case "done":
            return .done

        case "error":
            return (json["message"] as? String).map { .error($0) }

        default:
            return nil
        }
    }

    // MARK: - Card parser

    private static func parseCard(_ json: [String: Any]) -> SSEEvent? {
        guard let cardType = json["card_type"] as? String,
              let d        = json["data"] as? [String: Any] else { return nil }

        let card: AssistantCard?
        switch cardType {
        case "balance":
            card = .balance(
                checking: d["checking"] as? Double ?? 0,
                cardOwed: d["card_owed"] as? Double ?? 0,
                source:   d["source"]   as? String ?? "",
                age:      d["age"]      as? String ?? ""
            )
        case "alert_list":
            card = .alertList(
                items:  d["items"]  as? [String] ?? [],
                level:  d["level"]  as? String ?? "",
                source: d["source"] as? String ?? ""
            )
        case "lead_list":
            let rawItems = d["items"] as? [[String: Any]] ?? []
            let items = rawItems.map { item in
                AssistantCard.LeadItem(
                    title:   item["title"]   as? String ?? "",
                    company: item["company"] as? String,
                    score:   item["score"]   as? Int
                )
            }
            card = .leadList(items: items, source: d["source"] as? String ?? "")
        case "cashflow":
            card = .cashflow(
                income:   d["income"]   as? Double ?? 0,
                expenses: d["expenses"] as? Double ?? 0,
                net:      d["net"]      as? Double ?? 0,
                source:   d["source"]   as? String ?? ""
            )
        case "explain":
            card = .explain(
                headline: d["headline"] as? String ?? "",
                body:     d["body"]     as? String ?? ""
            )
        case "draft":
            card = .draft(
                to:      d["to"]      as? String ?? "",
                subject: d["subject"] as? String ?? "",
                body:    d["body"]    as? String ?? ""
            )
        case "reminder_confirm":
            let fireAt = (d["fire_at"] as? String)
                .flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
            card = .reminderConfirm(title: d["title"] as? String ?? "", fireAt: fireAt)
        case "brief":
            card = .brief(
                text:   d["text"]   as? String ?? "",
                source: d["source"] as? String ?? "",
                age:    d["age"]    as? String ?? ""
            )
        default:
            card = nil
        }

        return card.map { .card($0) }
    }
}
