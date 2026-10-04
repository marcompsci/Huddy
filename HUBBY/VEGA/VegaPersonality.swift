import Foundation

// MARK: - Persona settings (persisted in UserDefaults — not secrets)

@Observable
@MainActor
final class VegaPersonality {
    static let shared = VegaPersonality()
    private init() { load() }

    // Editable persona fields
    var assistantName: String = "VEGA"
    var callMeName:    String = ""       // "Call me …" override

    // Verbosity: "brief" | "normal" | "detailed"
    var verbosity: Verbosity = .normal

    enum Verbosity: String, CaseIterable {
        case brief, normal, detailed
        var label: String { rawValue.capitalized }
    }

    // MARK: - Backend headers (merged into every request)

    var requestContext: [String: String] {
        var d: [String: String] = [
            "assistant_name": assistantName,
            "verbosity":      verbosity.rawValue
        ]
        if !callMeName.isEmpty { d["user_name"] = callMeName }
        return d
    }

    // MARK: - Persistence

    private let defaults = UserDefaults.standard

    private func load() {
        assistantName = defaults.string(forKey: "vega.name")      ?? "VEGA"
        callMeName    = defaults.string(forKey: "vega.callme")    ?? ""
        verbosity     = Verbosity(rawValue: defaults.string(forKey: "vega.verbosity") ?? "") ?? .normal
    }

    func save() {
        defaults.set(assistantName, forKey: "vega.name")
        defaults.set(callMeName,    forKey: "vega.callme")
        defaults.set(verbosity.rawValue, forKey: "vega.verbosity")
    }
}

// MARK: - Memory item (returned by GET /v1/memory)

struct VegaMemoryItem: Identifiable, Codable {
    let id:        String
    let content:   String
    let createdAt: Date
}

// MARK: - Memory manager — GET/DELETE /v1/memory

@MainActor
final class VegaMemoryManager {
    static let shared = VegaMemoryManager()
    private init() {}

    private(set) var items: [VegaMemoryItem] = []

    // MARK: - Helpers

    private var sessionToken: String? { Keychain.get(Keychain.Keys.vegaSessionToken) }

    private func authorizedRequest(path: String, method: String = "GET") -> URLRequest? {
        guard
            let token = sessionToken, !token.isEmpty,
            let rawURL = Keychain.get(Keychain.Keys.vegaBackendURL), !rawURL.isEmpty,
            let url = URL(string: rawURL)?.appendingPathComponent(path)
        else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return req
    }

    // MARK: - CRUD

    func fetch() async {
        guard let req = authorizedRequest(path: "v1/memory") else { return }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([VegaMemoryItem].self, from: data)) ?? items
    }

    func delete(id: String) async {
        items.removeAll { $0.id == id }
        guard let req = authorizedRequest(path: "v1/memory/\(id)", method: "DELETE") else { return }
        _ = try? await URLSession.shared.data(for: req)
    }

    func forgetEverything() async {
        items = []
        guard let req = authorizedRequest(path: "v1/memory", method: "DELETE") else { return }
        _ = try? await URLSession.shared.data(for: req)
    }

    func forgetLastTurn() async {
        guard let last = items.last else { return }
        await delete(id: last.id)
    }
}
