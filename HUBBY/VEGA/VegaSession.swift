import Foundation

// MARK: - Conversation turn models

enum TurnRole: String, Codable { case user, assistant }

struct VegaTurn: Identifiable, Codable {
    let id:       UUID
    let role:     TurnRole
    var text:     String
    var cards:    [AssistantCard]
    let createdAt: Date

    init(role: TurnRole, text: String, cards: [AssistantCard] = []) {
        self.id        = UUID()
        self.role      = role
        self.text      = text
        self.cards     = cards
        self.createdAt = Date()
    }
}

// MARK: - Session: in-memory turns + disk persistence (last 20)

@MainActor
final class VegaSession {
    static let shared = VegaSession()
    private init() { load() }

    private(set) var turns: [VegaTurn] = []

    private let maxDisk = 20
    private var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.omari.morninghud")?
            .appendingPathComponent("VegaTurns.json")
    }

    // MARK: - Mutations

    func append(_ turn: VegaTurn) {
        turns.append(turn)
        save()
    }

    func updateLast(text: String, cards: [AssistantCard] = []) {
        guard !turns.isEmpty else { return }
        turns[turns.count - 1].text  = text
        turns[turns.count - 1].cards = cards
        save()
    }

    func clear() {
        turns = []
        save()
    }

    // MARK: - History sent to backend (last 20 turns)

    var historyForBackend: [[String: String]] {
        turns.suffix(maxDisk).map { ["role": $0.role.rawValue, "content": $0.text] }
    }

    // MARK: - Persistence

    private func save() {
        guard let url = fileURL else { return }
        let slice = Array(turns.suffix(maxDisk))
        try? JSONEncoder().encode(slice).write(to: url)
    }

    private func load() {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([VegaTurn].self, from: data) else { return }
        turns = decoded
    }
}
