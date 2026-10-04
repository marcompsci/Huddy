import Foundation

enum LeadSource: String, Codable, CaseIterable {
    case backstage = "Backstage"
    case indeed = "Indeed"
    case linkedin = "LinkedIn"
    case other = "Other"
}

struct JobLead: Identifiable, Codable {
    var id: String
    var messageId: String
    var title: String
    var role: String?
    var totalPay: Double
    var payUnit: String
    var hoursOrDays: Double?
    var isDay: Bool
    var hourlyEquivalent: Double
    var ageRange: String?
    var location: String?
    var projectType: String?
    var source: LeadSource
    var postedAgo: String?
    var receivedAt: Date
    var gmailLink: URL?
    // Set from snapshot payText; overrides the computed payDisplay when present
    var payTextOverride: String?

    var payDisplay: String {
        if let override = payTextOverride { return override }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: totalPay)) ?? "$\(Int(totalPay))"
        if payUnit == "hour" { return "\(formatted)/hr" }
        if payUnit == "month" { return "\(formatted)/mo" }
        if payUnit == "year" { return "\(formatted)/yr" }
        if isDay, let d = hoursOrDays {
            return "\(formatted) / \(Int(d)) \(d == 1 ? "day" : "days")"
        }
        if let h = hoursOrDays {
            return "\(formatted) / \(Int(h)) hr"
        }
        return "\(formatted)"
    }

    var isRecent: Bool { Date().timeIntervalSince(receivedAt) < 129_600 } // 36 hours
}
