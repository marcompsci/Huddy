import Foundation

struct FinanceOverview: Codable {
    var accounts: [Account]?
    var netWorth: NetWorth?
    var currentMonth: MonthSummary?
    var lastMonth: MonthSummary?
    var topCategories: [CategorySpend]?
    var warnings: [String]?
    var asOf: String?

    var checkingBalance: Double {
        accounts?.first { $0.type?.contains("Checking") == true }?.balance?.current ?? 0
    }
    var cardBalance: Double {
        accounts?.first { $0.type?.contains("Credit") == true }?.balance?.current ?? 0
    }
}

struct Account: Codable, Identifiable {
    var id: String { "\(institution ?? "")-\(accountMask ?? "")" }
    var name: String?
    var institution: String?
    var type: String?
    var accountMask: String?
    var balance: Balance?
}

struct Balance: Codable {
    var current: Double?
    var currency: String?
}

struct NetWorth: Codable {
    var amount: Double?
    var currencyCode: String?
}

struct MonthSummary: Codable {
    var label: String?
    var income: AmountWrapper?
    var spending: AmountWrapper?
    var net: AmountWrapper?
}

struct AmountWrapper: Codable {
    var amount: Double?
}

struct CategorySpend: Codable, Identifiable {
    var id: String { category ?? UUID().uuidString }
    var category: String?
    var amount: AmountWrapper?
    var percentOfTotal: Double?
}
