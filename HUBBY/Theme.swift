import SwiftUI

extension Color {
    static let void       = Color(hex: "#05090E")
    static let panel      = Color(hex: "#0A121A")
    static let panel2     = Color(hex: "#0E1923")
    static let line       = Color(hex: "#16303D")
    static let lineHot    = Color(hex: "#1F4E60")
    static let hudCyan    = Color(hex: "#5FE3FF")
    static let cyanDim    = Color(hex: "#2B8BA3")
    static let hudGold    = Color(hex: "#F5B841")
    static let goldDim    = Color(hex: "#8A6A2A")
    static let hudRed     = Color(hex: "#FF5340")
    static let hudGreen   = Color(hex: "#5BF0A5")
    static let hudText    = Color(hex: "#D6E8F0")
    static let dim        = Color(hex: "#7C95A3")
    static let faint      = Color(hex: "#46606E")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum HUDFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let uiFont = UIFont(name: weight == .bold ? "ChakraPetch-Bold" : "ChakraPetch-SemiBold", size: size)
        if let f = uiFont { return Font(f) }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = weight == .medium ? "JetBrainsMono-Medium" : "JetBrainsMono-Regular"
        if let f = UIFont(name: name, size: size) { return Font(f) }
        return .system(size: size, weight: weight, design: .monospaced)
    }
}
