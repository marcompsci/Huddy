import Foundation

protocol GmailService: Sendable {
    func fetchAlerts() async throws -> [MailAlert]
    func fetchLeads() async throws -> [JobLead]
}

// MARK: - Mock

final class MockGmailService: GmailService {
    func fetchAlerts() async throws -> [MailAlert] {
        try await Task.sleep(nanoseconds: 600_000_000)
        let now = Date()
        return [
            MailAlert(id: "mock-1", subject: "Critical security alert",
                      snippet: "A new sign-in to your Google account was detected from iOS device.",
                      sender: "no-reply@accounts.google.com", senderDomain: "accounts.google.com",
                      receivedAt: now.addingTimeInterval(-3600), severity: .critical,
                      classificationLabel: "New sign-in",
                      gmailLink: URL(string: "googlegmail://"),
                      dismissed: false),
            MailAlert(id: "mock-2", subject: "Your Experian Score Changed",
                      snippet: "Your credit score went up 12 points this month.",
                      sender: "alerts@usa.experian.com", senderDomain: "usa.experian.com",
                      receivedAt: now.addingTimeInterval(-86000), severity: .warning,
                      classificationLabel: "Score moved",
                      gmailLink: URL(string: "googlegmail://"),
                      dismissed: false),
            MailAlert(id: "mock-3", subject: "Payment Received – Capital One",
                      snippet: "Your payment of $200 has been received and applied to your account.",
                      sender: "no-reply@capitalone.com", senderDomain: "capitalone.com",
                      receivedAt: now.addingTimeInterval(-172800), severity: .info,
                      classificationLabel: "Payment",
                      gmailLink: URL(string: "googlegmail://"),
                      dismissed: false),
        ]
    }

    func fetchLeads() async throws -> [JobLead] {
        try await Task.sleep(nanoseconds: 700_000_000)
        let now = Date()
        return [
            JobLead(id: "mock-lead-1", messageId: "mock-msg-1",
                    title: "Social Media Scripted Comedy Video",
                    role: "Comedic Gen Z / Young Millennial Lead",
                    totalPay: 400, payUnit: "day", hoursOrDays: 1, isDay: true,
                    hourlyEquivalent: 50,
                    ageRange: "20-30", location: "Nationwide",
                    projectType: "Online Commercial / Video Ad · Nonunion",
                    source: .backstage, postedAgo: "1 day, 13 hours ago",
                    receivedAt: now.addingTimeInterval(-3600),
                    gmailLink: URL(string: "googlegmail://")),
            JobLead(id: "mock-lead-2", messageId: "mock-msg-2",
                    title: "Food Truth",
                    role: "Narrator Voiceover, Male",
                    totalPay: 300, payUnit: "hour", hoursOrDays: 5, isDay: false,
                    hourlyEquivalent: 60,
                    ageRange: "40-59", location: "Nationwide",
                    projectType: "Audiobook · Union",
                    source: .backstage, postedAgo: "1 day, 18 hours ago",
                    receivedAt: now.addingTimeInterval(-7200),
                    gmailLink: URL(string: "googlegmail://")),
            JobLead(id: "mock-lead-3", messageId: "mock-msg-3",
                    title: "Software Engineer",
                    role: nil,
                    totalPay: 5000, payUnit: "month", hoursOrDays: 173, isDay: false,
                    hourlyEquivalent: 28.9,
                    ageRange: nil, location: "Remote",
                    projectType: nil,
                    source: .indeed, postedAgo: nil,
                    receivedAt: now.addingTimeInterval(-18000),
                    gmailLink: URL(string: "googlegmail://")),
        ]
    }
}

// MARK: - Live Gmail service

actor LiveGmailService: GmailService {
    private let session: URLSession
    private var accessToken: String?
    private let leadsCache = LeadsCache()

    nonisolated init() {
        self.session = URLSession.shared
    }

    func setAccessToken(_ token: String) {
        self.accessToken = token
    }

    func fetchAlerts() async throws -> [MailAlert] {
        guard let token = accessToken else { throw ServiceError.noCredentials }
        let messages = try await listMessages(query: GmailQueries.threatScan, maxResults: 20, token: token)
        var alerts: [MailAlert] = []
        for msg in messages {
            let full = try await fetchMessage(id: msg.id, token: token)
            let subject = header(named: "Subject", in: full) ?? "(no subject)"
            let from = header(named: "From", in: full) ?? ""
            let domain = extractDomain(from: from)
            let snippet = full.snippet ?? ""
            let (severity, label) = MailClassifier.classify(subject: subject, snippet: snippet, sender: from)
            let alert = MailAlert(
                id: full.id,
                subject: subject,
                snippet: snippet,
                sender: from,
                senderDomain: domain,
                receivedAt: full.receivedDate,
                severity: severity,
                classificationLabel: label,
                gmailLink: URL(string: "googlegmail://co?message_id=\(full.id)"),
                dismissed: false
            )
            alerts.append(alert)
        }
        return alerts
    }

    func fetchLeads() async throws -> [JobLead] {
        guard let token = accessToken else { throw ServiceError.noCredentials }
        let messages = try await listMessages(query: GmailQueries.leadScan, maxResults: 10, token: token)
        var allLeads: [JobLead] = []
        try await withThrowingTaskGroup(of: [JobLead].self) { group in
            for msg in messages {
                group.addTask {
                    if let cached = await self.leadsCache.get(messageId: msg.id) { return cached }
                    let full = try await self.fetchMessage(id: msg.id, token: token)
                    let bodyText = HTMLText.extractBody(from: full.payload ?? MessagePayload(headers: nil, parts: nil, body: nil, mimeType: nil))
                    let subject = self.header(named: "Subject", in: full) ?? ""
                    let from = self.header(named: "From", in: full) ?? ""
                    let source = self.detectSource(from: from)
                    let link = URL(string: "googlegmail://co?message_id=\(msg.id)")
                    let leads = PayExtractor.extractLeads(from: bodyText, messageId: msg.id, receivedAt: full.receivedDate, source: source, subject: subject, gmailLink: link)
                    await self.leadsCache.set(messageId: msg.id, leads: leads)
                    return leads
                }
            }
            for try await leads in group { allLeads.append(contentsOf: leads) }
        }
        return allLeads
    }

    private func listMessages(query: String, maxResults: Int, token: String) async throws -> [GmailMessage] {
        var comps = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: "\(maxResults)")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: req)
        let list = try JSONDecoder().decode(MessageListResponse.self, from: data)
        return list.messages ?? []
    }

    private func fetchMessage(id: String, token: String) async throws -> GmailMessage {
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw ServiceError.unauthorized
        }
        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }

    nonisolated private func header(named name: String, in message: GmailMessage) -> String? {
        message.payload?.headers?.first { $0.name?.lowercased() == name.lowercased() }?.value
    }

    nonisolated private func extractDomain(from sender: String) -> String {
        if let atRange = sender.range(of: "@") {
            let after = String(sender[atRange.upperBound...])
            return after.replacingOccurrences(of: ">", with: "").trimmingCharacters(in: .whitespaces)
        }
        return sender
    }

    nonisolated private func detectSource(from sender: String) -> LeadSource {
        let s = sender.lowercased()
        if s.contains("backstage") { return .backstage }
        if s.contains("indeed") { return .indeed }
        if s.contains("linkedin") { return .linkedin }
        return .other
    }
}

private struct MessageListResponse: Decodable {
    var messages: [GmailMessage]?
}

// MARK: - Leads cache

actor LeadsCache {
    private var cache: [String: [JobLead]] = [:]
    private let fileURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("leads_cache.json")
    }()

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: [JobLead]].self, from: data) {
            cache = decoded
        }
    }

    func get(messageId: String) -> [JobLead]? { cache[messageId] }

    func set(messageId: String, leads: [JobLead]) {
        cache[messageId] = leads
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: fileURL)
        }
    }
}
