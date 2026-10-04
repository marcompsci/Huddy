import Foundation

enum Severity: Int, Comparable, Codable {
    case info = 0
    case warning = 1
    case critical = 2

    static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .critical: return "CRITICAL"
        case .warning: return "WARNING"
        case .info: return "INFO"
        }
    }
}

struct MailAlert: Identifiable, Codable {
    var id: String
    var subject: String
    var snippet: String
    var sender: String
    var senderDomain: String
    var receivedAt: Date
    var severity: Severity
    var classificationLabel: String
    var gmailLink: URL?
    var dismissed: Bool = false

    var isNew: Bool { Date().timeIntervalSince(receivedAt) < 86400 }
    var relativeTime: String {
        let interval = Date().timeIntervalSince(receivedAt)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

struct GmailMessage: Identifiable, Codable {
    var id: String
    var threadId: String?
    var snippet: String?
    var payload: MessagePayload?
    var internalDate: String?

    var receivedDate: Date {
        guard let ms = internalDate, let ts = Double(ms) else { return Date() }
        return Date(timeIntervalSince1970: ts / 1000)
    }
}

struct MessagePayload: Codable {
    var headers: [MessageHeader]?
    var parts: [MessagePart]?
    var body: MessageBody?
    var mimeType: String?
}

struct MessageHeader: Codable {
    var name: String?
    var value: String?
}

struct MessagePart: Codable {
    var mimeType: String?
    var body: MessageBody?
    var parts: [MessagePart]?
}

struct MessageBody: Codable {
    var data: String?
    var size: Int?
}
