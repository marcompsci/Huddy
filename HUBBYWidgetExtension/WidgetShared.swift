import Foundation
import SwiftUI

// MARK: - App Group

let kWidgetAppGroup = "group.com.omari.morninghud"

// MARK: - Data model (mirrors main app WidgetData; JSON written by DashboardStore.writeSnapshot)

struct WidgetData: Codable {
    var checking: Double
    var cardOwed: Double
    var threatLevel: ThreatLevel
    var headline: String
    var topLeadPayText: String?
    var topLeadTitle: String?
    var generatedAt: Date

    var isStale: Bool { Date().timeIntervalSince(generatedAt) > 93_600 }

    var freshnessLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE HH:mm"
        return f.string(from: generatedAt)
    }

    // Plain decoder — matches DashboardStore's plain JSONEncoder() (no key conversion, deferredToDate)
    static var decoder: JSONDecoder { JSONDecoder() }
}

extension WidgetData {
    static var preview: WidgetData {
        WidgetData(
            checking: 2847.50,
            cardOwed: 342.18,
            threatLevel: .allClear,
            headline: "Cash flow positive. Two new leads in. No critical alerts.",
            topLeadPayText: "$85/hr",
            topLeadTitle: "Senior iOS Developer",
            generatedAt: Date().addingTimeInterval(-3600)
        )
    }
}

// MARK: - Threat level (mirrors main app ThreatLevel; same raw values for Codable compatibility)

enum ThreatLevel: String, Codable {
    case alert    = "ALERT"
    case watch    = "WATCH"
    case allClear = "ALL CLEAR"

    var color: Color {
        switch self {
        case .alert:    return .hudRed
        case .watch:    return .hudGold
        case .allClear: return .hudCyan
        }
    }

    var systemIcon: String {
        switch self {
        case .alert:    return "exclamationmark.triangle.fill"
        case .watch:    return "eye.fill"
        case .allClear: return "checkmark.circle.fill"
        }
    }
}

// MARK: - HUD theme (widget copy — same hex values as main app Theme.swift)

extension Color {
    static let void    = Color(widgetHex: "#05090E")
    static let panel   = Color(widgetHex: "#0A121A")
    static let hudCyan = Color(widgetHex: "#5FE3FF")
    static let cyanDim = Color(widgetHex: "#2B8BA3")
    static let hudGold = Color(widgetHex: "#F5B841")
    static let hudRed  = Color(widgetHex: "#FF5340")
    static let hudGreen = Color(widgetHex: "#5BF0A5")
    static let hudText = Color(widgetHex: "#D6E8F0")
    static let dim     = Color(widgetHex: "#7C95A3")
    static let faint   = Color(widgetHex: "#46606E")

    init(widgetHex hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >>  8) & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }
}

// MARK: - HUD fonts (widget copy)

enum HUDFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let name = weight == .bold ? "ChakraPetch-Bold" : "ChakraPetch-SemiBold"
        if let f = UIFont(name: name, size: size) { return Font(f) }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = weight == .medium ? "JetBrainsMono-Medium" : "JetBrainsMono-Regular"
        if let f = UIFont(name: name, size: size) { return Font(f) }
        return .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Currency formatter

func hudCurrency(_ amount: Double, cents: Bool = false) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    f.maximumFractionDigits = cents ? 2 : 0
    f.minimumFractionDigits = cents ? 2 : 0
    return f.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
}
