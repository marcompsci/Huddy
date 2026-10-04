import Foundation

enum PayExtractor {

    // MARK: - Public entry point

    static func extractLeads(from text: String, messageId: String, receivedAt: Date, source: LeadSource, subject: String, gmailLink: URL? = nil) -> [JobLead] {
        switch source {
        case .backstage:
            return extractBackstage(text: text, messageId: messageId, receivedAt: receivedAt, gmailLink: gmailLink)
        case .indeed, .linkedin, .other:
            return extractBoard(text: text, messageId: messageId, receivedAt: receivedAt, source: source, subject: subject, gmailLink: gmailLink)
        }
    }

    // MARK: - Backstage extraction

    private static func extractBackstage(text: String, messageId: String, receivedAt: Date, gmailLink: URL?) -> [JobLead] {
        var leads: [JobLead] = []
        // Find each pay block
        let payPattern = #"Estimated pay amount:\s*(\$[\d,]+(?:\.\d+)?)\s*for\s*(\d+(?:\.\d+)?)\s*(hours?|days?)\s*of work"#
        guard let payRegex = try? NSRegularExpression(pattern: payPattern, options: .caseInsensitive) else { return [] }
        let ns = text as NSString
        let matches = payRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))

        for match in matches {
            guard match.numberOfRanges >= 4 else { continue }
            let amtStr = ns.substring(with: match.range(at: 1))
            let qtyStr = ns.substring(with: match.range(at: 2))
            let unitStr = ns.substring(with: match.range(at: 3)).lowercased()

            let amount = parseAmount(amtStr) ?? 0
            let qty = Double(qtyStr) ?? 1
            let isDay = unitStr.hasPrefix("day")
            let hours = isDay ? qty * 8 : qty
            let hourly = hours > 0 ? amount / hours : 0

            let matchStart = match.range.location
            let blockStart = findBlockStart(in: text, before: matchStart)
            let block = ns.substring(with: NSRange(location: blockStart, length: matchStart - blockStart))

            // Extract fields from block
            let posted = extractPosted(from: block)
            let title = extractTitle(from: block)
            let projectType = extractProjectType(from: block)
            let location = extractLocation(from: block)
            let (role, ageRange) = extractRoleAndAge(from: block)

            // Ignore referral amounts
            let contextStart = max(0, matchStart - 60)
            let contextLen = min(120, ns.length - contextStart)
            let context = ns.substring(with: NSRange(location: contextStart, length: contextLen)).lowercased()
            if shouldIgnore(context: context) { continue }

            let lead = JobLead(
                id: "\(messageId)-backstage-\(leads.count)",
                messageId: messageId,
                title: title,
                role: role,
                totalPay: amount,
                payUnit: isDay ? "day" : "hour",
                hoursOrDays: qty,
                isDay: isDay,
                hourlyEquivalent: hourly,
                ageRange: ageRange,
                location: location,
                projectType: projectType,
                source: .backstage,
                postedAgo: posted,
                receivedAt: receivedAt,
                gmailLink: gmailLink
            )
            leads.append(lead)
        }
        return leads
    }

    private static func findBlockStart(in text: String, before position: Int) -> Int {
        let ns = text as NSString
        let searchRange = NSRange(location: 0, length: position)
        // Look backward for "Posted " to find block boundary
        let postedPattern = #"Posted "#
        guard let regex = try? NSRegularExpression(pattern: postedPattern) else { return 0 }
        let matches = regex.matches(in: text, range: searchRange)
        return matches.last?.range.location ?? 0
    }

    private static func extractPosted(from block: String) -> String? {
        let pattern = #"Posted (.+?ago)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = block as NSString
        if let m = regex.firstMatch(in: block, range: NSRange(location: 0, length: ns.length)) {
            return ns.substring(with: m.range(at: 1))
        }
        return nil
    }

    private static func extractTitle(from block: String) -> String {
        // Find quoted string after "ago"
        let quotedPattern = #"ago\s+"([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: quotedPattern, options: .caseInsensitive) {
            let ns = block as NSString
            if let m = regex.firstMatch(in: block, range: NSRange(location: 0, length: ns.length)) {
                return ns.substring(with: m.range(at: 1))
            }
        }
        // Fallback: text between "ago" and " Casting" / " Seeking"
        let fallbackPattern = #"ago\s+(.+?)(?:\s+Casting|\s+Seeking)"#
        if let regex = try? NSRegularExpression(pattern: fallbackPattern, options: .caseInsensitive) {
            let ns = block as NSString
            if let m = regex.firstMatch(in: block, range: NSRange(location: 0, length: ns.length)) {
                return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        return "Untitled"
    }

    private static func extractProjectType(from block: String) -> String? {
        let pattern = #"(.+?)\$\s*Paid"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let ns = block as NSString
            if let m = regex.firstMatch(in: block, range: NSRange(location: 0, length: ns.length)) {
                return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func extractLocation(from block: String) -> String? {
        let pattern = #"Seeking talent from:\s*(\S+(?:\s+\S+)?)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let ns = block as NSString
            if let m = regex.firstMatch(in: block, range: NSRange(location: 0, length: ns.length)) {
                return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func extractRoleAndAge(from block: String) -> (String?, String?) {
        // Age range at end of role: NN-NN or NN+
        let agePattern = #"(\d{2}(?:-\d{2}|\+))\s*$"#
        let lines = block.components(separatedBy: "\n")
        // Look for a line with age range near "Estimated pay amount"
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if let regex = try? NSRegularExpression(pattern: agePattern) {
                let ns = trimmed as NSString
                if let m = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) {
                    let age = ns.substring(with: m.range(at: 1))
                    let role = String(trimmed.prefix(trimmed.count - age.count)).trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ","))
                    return (role.isEmpty ? nil : role, age)
                }
            }
        }
        return (nil, nil)
    }

    // MARK: - General job board extraction

    private static func extractBoard(text: String, messageId: String, receivedAt: Date, source: LeadSource, subject: String, gmailLink: URL?) -> [JobLead] {
        // Match pay ranges and single amounts
        let pattern = #"(\$[\d,.]+k?)(?:\s*(?:-|–|to)\s*(\$[\d,.]+k?))?\s*(?:/|a |an |per )?(hour|hr|day|week|month|year|yr|annually)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))

        var leads: [JobLead] = []
        var seenAmounts: Set<String> = []

        for match in matches {
            guard match.numberOfRanges >= 4 else { continue }
            let lo = ns.substring(with: match.range(at: 1))
            let hiStr = match.range(at: 2).location != NSNotFound ? ns.substring(with: match.range(at: 2)) : nil
            let unit = ns.substring(with: match.range(at: 3)).lowercased()

            // Check context for ignore keywords
            let contextStart = max(0, match.range.location - 60)
            let contextLen = min(120, ns.length - contextStart)
            let context = ns.substring(with: NSRange(location: contextStart, length: contextLen)).lowercased()
            if shouldIgnore(context: context) { continue }

            let loVal = parseAmount(lo) ?? 0
            let hiVal = hiStr.flatMap { parseAmount($0) }
            let hoursPerUnit = hoursFor(unit: unit)
            let hourly = loVal / hoursPerUnit

            let key = "\(lo)-\(hiStr ?? "")-\(unit)"
            if seenAmounts.contains(key) { continue }
            seenAmounts.insert(key)

            // Title from subject: "Role @ Company" or just subject
            let parts = subject.components(separatedBy: " @ ")
            let title = parts.first?.trimmingCharacters(in: .whitespaces) ?? subject

            // Location: first "City, ST NNNNN" or "City, ST"
            let locPattern = #"([A-Z][a-zA-Z\s]+,\s*[A-Z]{2}(?:\s+\d{5})?)"#
            var location: String? = nil
            if let locRegex = try? NSRegularExpression(pattern: locPattern) {
                if let lm = locRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
                    let raw = ns.substring(with: lm.range(at: 1))
                    // Strip zip
                    location = raw.replacingOccurrences(of: #"\s+\d{5}"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                }
            }

            var displayPay: String
            let unitLabel: String
            switch unit {
            case "hour", "hr": unitLabel = "hr"
            case "day": unitLabel = "day"
            case "week": unitLabel = "wk"
            case "month": unitLabel = "mo"
            case "year", "yr", "annually": unitLabel = "yr"
            default: unitLabel = unit
            }

            if let hi = hiVal {
                let loFmt = formatAmount(loVal)
                let hiFmt = formatAmount(hi)
                displayPay = "\(loFmt)–\(hiFmt) / \(unitLabel)"
            } else {
                displayPay = "\(formatAmount(loVal)) / \(unitLabel)"
            }

            let lead = JobLead(
                id: "\(messageId)-board-\(leads.count)",
                messageId: messageId,
                title: title,
                role: nil,
                totalPay: loVal,
                payUnit: unit,
                hoursOrDays: hoursPerUnit,
                isDay: unit == "day",
                hourlyEquivalent: hourly,
                ageRange: nil,
                location: location,
                projectType: nil,
                source: source,
                postedAgo: nil,
                receivedAt: receivedAt,
                gmailLink: gmailLink
            )
            leads.append(lead)
        }
        return leads
    }

    // MARK: - Helpers

    private static func parseAmount(_ str: String) -> Double? {
        var s = str.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        let isK = s.hasSuffix("k") || s.hasSuffix("K")
        if isK { s = String(s.dropLast()) }
        guard let val = Double(s) else { return nil }
        return isK ? val * 1000 : val
    }

    private static func formatAmount(_ val: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: val)) ?? "$\(Int(val))"
    }

    private static func hoursFor(unit: String) -> Double {
        switch unit.lowercased() {
        case "hour", "hr": return 1
        case "day": return 8
        case "week": return 40
        case "month": return 173
        case "year", "yr", "annually": return 2080
        default: return 1
        }
    }

    private static func shouldIgnore(context: String) -> Bool {
        let ignoreTerms = ["refer", "gift card", "credit limit", "minimum base pay", "bonus", "cash back"]
        return ignoreTerms.contains { context.contains($0) }
    }
}
