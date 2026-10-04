import Foundation

// MARK: - Mock backend — streams scripted SSE events with realistic delays

final class MockAssistantBackend: AssistantBackend, @unchecked Sendable {

    func stream(
        userText: String,
        history: [[String: String]],
        snapshot: SnapshotPayload?
    ) -> AsyncThrowingStream<SSEEvent, Error> {

        let lower = userText.lowercased()
        let script = selectScript(for: lower, snapshot: snapshot)

        return AsyncThrowingStream { continuation in
            Task {
                for event in script {
                    switch event {
                    case .delay(let ms):
                        try? await Task.sleep(for: .milliseconds(ms))
                    case .sse(let e):
                        continuation.yield(e)
                    }
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Script selection

    private enum ScriptStep {
        case delay(Int)
        case sse(SSEEvent)
    }

    private func selectScript(for lower: String, snapshot: SnapshotPayload?) -> [ScriptStep] {
        if lower.contains("balance") || lower.contains("checking") {
            return balanceScript(snapshot: snapshot)
        } else if lower.contains("alert") || lower.contains("threat") {
            return alertScript(snapshot: snapshot)
        } else if lower.contains("lead") || lower.contains("job") {
            return leadsScript(snapshot: snapshot)
        } else if lower.contains("brief") || lower.contains("morning") {
            return briefScript(snapshot: snapshot)
        } else if lower.contains("cash") || lower.contains("flow") {
            return cashflowScript(snapshot: snapshot)
        } else {
            return generalScript(snapshot: snapshot)
        }
    }

    // MARK: - Scripted responses

    private func balanceScript(snapshot: SnapshotPayload?) -> [ScriptStep] {
        let checking = snapshot?.checking ?? 2_847.50
        let card     = snapshot?.cardOwed ?? 342.18
        return [
            .delay(600),
            .sse(.toolStatus("Fetching snapshot…")),
            .delay(400),
            .sse(.card(.balance(checking: checking, cardOwed: card, source: "Snapshot", age: "6m ago"))),
            .delay(200),
            .sse(.textDelta("Your checking balance is ")),
            .delay(80),
            .sse(.textDelta(hudSpoken(checking) + ".")),
            .delay(80),
            .sse(.textDelta(" Your card balance owed is ")),
            .delay(80),
            .sse(.textDelta(hudSpoken(card) + ".")),
            .delay(80),
            .sse(.textDelta(" Net liquid position is ")),
            .delay(80),
            .sse(.textDelta(hudSpoken(checking - card) + ".")),
            .delay(100),
            .sse(.done),
        ]
    }

    private func alertScript(snapshot: SnapshotPayload?) -> [ScriptStep] {
        let items   = snapshot?.alerts ?? ["No critical alerts at this time."]
        let level   = snapshot?.threat ?? "ALL CLEAR"
        return [
            .delay(500),
            .sse(.toolStatus("Scanning threat data…")),
            .delay(400),
            .sse(.card(.alertList(items: items, level: level, source: "Snapshot"))),
            .delay(200),
            .sse(.textDelta("Threat status is ")),
            .delay(80),
            .sse(.textDelta(level + ". ")),
            .delay(80),
            .sse(.textDelta("I found \(items.count) alert\(items.count == 1 ? "" : "s"). ")),
            .delay(80),
            .sse(.textDelta(items.first ?? "")),
            .delay(100),
            .sse(.done),
        ]
    }

    private func leadsScript(snapshot: SnapshotPayload?) -> [ScriptStep] {
        let rawLeads = snapshot?.leads ?? ["Senior iOS Developer", "Remote Swift Engineer", "Mobile Lead"]
        let items    = rawLeads.prefix(3).map { AssistantCard.LeadItem(title: $0, company: nil, score: nil) }
        return [
            .delay(500),
            .sse(.toolStatus("Pulling top leads…")),
            .delay(400),
            .sse(.card(.leadList(items: Array(items), source: "Snapshot"))),
            .delay(200),
            .sse(.textDelta("You have \(items.count) active lead\(items.count == 1 ? "" : "s"). ")),
            .delay(80),
            .sse(.textDelta("Your top lead is \(items.first?.title ?? "none"). ")),
            .delay(100),
            .sse(.done),
        ]
    }

    private func briefScript(snapshot: SnapshotPayload?) -> [ScriptStep] {
        let checking = snapshot?.checking ?? 2_847.50
        let card     = snapshot?.cardOwed ?? 342.18
        let threat   = snapshot?.threat ?? "ALL CLEAR"
        let briefText = "Good morning. Checking at \(hudSpoken(checking)), card owed \(hudSpoken(card)). Threat level: \(threat). No critical items require immediate action."
        return [
            .delay(700),
            .sse(.toolStatus("Composing brief…")),
            .delay(500),
            .sse(.card(.brief(text: briefText, source: "Snapshot", age: "6m ago"))),
            .delay(200),
            .sse(.textDelta("Good morning. ")),
            .delay(100),
            .sse(.textDelta("Your checking is at ")),
            .delay(60),
            .sse(.textDelta(hudSpoken(checking) + ". ")),
            .delay(60),
            .sse(.textDelta("Card balance owed: ")),
            .delay(60),
            .sse(.textDelta(hudSpoken(card) + ". ")),
            .delay(60),
            .sse(.textDelta("Threat level is \(threat). ")),
            .delay(60),
            .sse(.textDelta("No critical items require immediate action.")),
            .delay(100),
            .sse(.done),
        ]
    }

    private func cashflowScript(snapshot: SnapshotPayload?) -> [ScriptStep] {
        let income   = 4_200.0
        let expenses = 2_800.0
        return [
            .delay(500),
            .sse(.card(.cashflow(income: income, expenses: expenses, net: income - expenses, source: "Snapshot"))),
            .delay(200),
            .sse(.textDelta("This month: income ")),
            .delay(80),
            .sse(.textDelta(hudSpoken(income) + ", expenses ")),
            .delay(80),
            .sse(.textDelta(hudSpoken(expenses) + ". ")),
            .delay(80),
            .sse(.textDelta("Net is positive at " + hudSpoken(income - expenses) + ".")),
            .delay(100),
            .sse(.done),
        ]
    }

    private func generalScript(snapshot: SnapshotPayload?) -> [ScriptStep] {
        [
            .delay(400),
            .sse(.textDelta("I'm here. ")),
            .delay(80),
            .sse(.textDelta("Ask me about your balance, alerts, leads, or request your morning brief.")),
            .delay(100),
            .sse(.done),
        ]
    }
}

// MARK: - Money-to-speech formatter

private func hudSpoken(_ amount: Double) -> String {
    let abs = Swift.abs(amount)
    let prefix = amount < 0 ? "negative " : ""
    if abs >= 1_000 {
        return prefix + String(format: "$%.1fK", abs / 1_000)
    }
    return prefix + String(format: "$%.2f", abs)
}
