import Foundation

enum HTMLText {
    static func toPlain(_ html: String) -> String {
        var text = html

        // Remove style, script, head blocks entirely
        for tag in ["style", "script", "head"] {
            let pattern = "(?i)<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        // Strip remaining tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&nbsp;", " "), ("&quot;", "\""), ("&#39;", "'"),
            ("&apos;", "'"), ("&mdash;", "—"), ("&ndash;", "–"),
            ("&hellip;", "…"), ("&rsquo;", "'"), ("&lsquo;", "'"),
            ("&rdquo;", "\""), ("&ldquo;", "\""),
        ]
        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }
        // Numeric entities
        text = text.replacingOccurrences(of: "&#(\\d+);", with: "", options: .regularExpression)

        // Remove zero-width characters
        text = text.unicodeScalars.filter { scalar in
            let v = scalar.value
            return v != 0x200B && v != 0x200C && v != 0x200D && v != 0xFEFF && v != 0x00AD
        }.reduce("") { $0 + String($1) }

        // Collapse whitespace
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeBase64URL(_ encoded: String) -> String? {
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func extractBody(from payload: MessagePayload) -> String {
        // Prefer text/html, fallback to text/plain
        if let html = findPart(in: payload, mimeType: "text/html") {
            return toPlain(html)
        }
        if let plain = findPart(in: payload, mimeType: "text/plain") {
            return plain
        }
        return ""
    }

    private static func findPart(in payload: MessagePayload, mimeType: String) -> String? {
        if payload.mimeType == mimeType, let data = payload.body?.data {
            return decodeBase64URL(data)
        }
        if let parts = payload.parts {
            for part in parts {
                let fakeParts = MessagePayload(headers: nil, parts: part.parts, body: part.body, mimeType: part.mimeType)
                if let found = findPart(in: fakeParts, mimeType: mimeType) { return found }
            }
        }
        return nil
    }
}
