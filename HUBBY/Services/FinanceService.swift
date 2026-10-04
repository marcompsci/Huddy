import Foundation

protocol FinanceService: Sendable {
    func fetchOverview() async throws -> FinanceOverview
}

// MARK: - Mock

final class MockFinanceService: FinanceService {
    func fetchOverview() async throws -> FinanceOverview {
        try await Task.sleep(nanoseconds: 800_000_000)
        return FinanceOverview(
            accounts: [
                Account(name: "360 Checking", institution: "Capital One", type: "Checking",
                        accountMask: "8079", balance: Balance(current: 609.95, currency: "USD")),
                Account(name: "Platinum", institution: "Capital One", type: "CreditCard",
                        accountMask: "2442", balance: Balance(current: 247.50, currency: "USD")),
            ],
            netWorth: NetWorth(amount: 362.45, currencyCode: "USD"),
            currentMonth: MonthSummary(
                label: "October 1–2, 2026",
                income: AmountWrapper(amount: 0),
                spending: AmountWrapper(amount: 143.20),
                net: AmountWrapper(amount: -143.20)
            ),
            lastMonth: MonthSummary(
                label: "September 2026",
                income: AmountWrapper(amount: 2400),
                spending: AmountWrapper(amount: 1987.50),
                net: AmountWrapper(amount: 412.50)
            ),
            topCategories: [
                CategorySpend(category: "Transfers and card payments", amount: AmountWrapper(amount: 1940), percentOfTotal: 97.5),
                CategorySpend(category: "Food & Dining", amount: AmountWrapper(amount: 32.10), percentOfTotal: 1.6),
                CategorySpend(category: "Shopping", amount: AmountWrapper(amount: 15.40), percentOfTotal: 0.8),
            ],
            warnings: ["SAMPLE — Era Context not connected. Add credentials in Settings."],
            asOf: "2026-10-01"
        )
    }
}

// MARK: - Era live service

final class EraFinanceService: FinanceService {
    private let baseURL: String
    private let endpointPath: String
    private let apiKey: String

    init(baseURL: String, endpointPath: String, apiKey: String) {
        self.baseURL = baseURL
        self.endpointPath = endpointPath
        self.apiKey = apiKey
    }

    func fetchOverview() async throws -> FinanceOverview {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces) + endpointPath) else {
            throw ServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        if http.statusCode == 401 { throw ServiceError.unauthorized }
        guard http.statusCode == 200 else { throw ServiceError.httpError(http.statusCode) }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(FinanceOverview.self, from: data)
    }
}

enum ServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(Int)
    case noCredentials

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL — check your Era base URL in Settings."
        case .invalidResponse: return "Unexpected response from server."
        case .unauthorized: return "Check your Era API key in Settings."
        case .httpError(let code): return "Server returned HTTP \(code)."
        case .noCredentials: return "No credentials found — check Settings."
        }
    }
}
