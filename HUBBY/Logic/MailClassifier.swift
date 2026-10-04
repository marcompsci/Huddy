import Foundation

enum MailClassifier {
    static func classify(subject: String, snippet: String, sender: String) -> (Severity, String) {
        let text = "\(subject) \(snippet)".lowercased()
        let sub = subject.lowercased()
        let snip = snippet.lowercased()
        let from = sender.lowercased()

        // 1. Declined
        if text.contains("declined") {
            return (.critical, "Declined purchase")
        }

        // 2. Google security
        if from.contains("accounts.google.com") || text.contains("critical security alert") {
            if text.contains("new sign-in") || text.contains("signed in") {
                return (.critical, "New sign-in")
            }
            if text.contains("access to your google account") || text.contains("granted access") {
                return (.critical, "App granted access")
            }
            return (.warning, "Security alert")
        }

        // 3. Collection
        if text.contains("collection account") || text.contains("collections") {
            return (.critical, "Collection account")
        }

        // 4. Tradeline
        if text.contains("tradeline") || text.contains("new account opened") || text.contains("new account reported") {
            return (.critical, "New tradeline")
        }

        // 5. SSN
        if text.contains("ssn") || text.contains("social security number") {
            return (.critical, "SSN alert")
        }

        // 6. Hard inquiry
        if text.contains("hard inquiry") || text.contains("new inquiry") {
            return (.warning, "Credit inquiry")
        }

        // 7. Score change
        if text.contains("score changed") || text.contains("score dropped") ||
           text.contains("score went up") || text.contains("score went down") {
            return (.warning, "Score moved")
        }

        // 8. Payment
        if (text.contains("payment") && (text.contains("scheduled") || text.contains("receipt") ||
            text.contains("posted") || text.contains("received"))) {
            return (.info, "Payment")
        }

        // 9. Zelle / money movement
        if text.contains("zelle") || text.contains("sent you money") || text.contains("you sent money") {
            return (.info, "Money movement")
        }

        // 10. Fallthrough
        return (.info, "Issuer / promo")
    }
}
