import Foundation
import Observation
import WidgetKit
import ActivityKit

enum ConnectionState: Equatable {
    case idle, loading, connected, error(String)
    var dot: DotState {
        switch self {
        case .idle:       return .idle
        case .loading:    return .loading
        case .connected:  return .connected
        case .error:      return .error
        }
    }
    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.connected, .connected): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

enum DotState { case idle, loading, connected, error }

private let kAppGroup = "group.com.omari.morninghud"

@Observable
@MainActor
final class DashboardStore {

    // MARK: - Snapshot (primary data source)
    var snapshot: HUDSnapshot? = nil
    var snapshotState: ConnectionState = .idle
    var snapshotRefreshedAt: Date? = nil

    // MARK: - Mapped legacy properties (populated from snapshot)
    var finance: FinanceOverview? = nil
    var financeState: ConnectionState = .idle
    var financeRefreshedAt: Date? = nil
    var alerts: [MailAlert] = []
    var alertsState: ConnectionState = .idle
    var alertsRefreshedAt: Date? = nil
    var leads: [JobLead] = []
    var leadsState: ConnectionState = .idle
    var leadsRefreshedAt: Date? = nil

    // MARK: - Dismissed
    var dismissedAlertIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "dismissed_alerts") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "dismissed_alerts") }
    }

    // MARK: - Settings
    var useSampleData: Bool {
        get { UserDefaults.standard.bool(forKey: "use_sample_data") }
        set { UserDefaults.standard.set(newValue, forKey: "use_sample_data") }
    }
    var lowBalanceThreshold: Double {
        get {
            let v = UserDefaults.standard.double(forKey: "low_balance_threshold")
            return v == 0 ? 100 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: "low_balance_threshold") }
    }

    // MARK: - Gmail auth (wired in Phase 3)
    var isGmailConnected: Bool = false
    var gmailUserEmail: String? = nil

    // MARK: - Log
    var logEntries: [LogEntry] = []

    // MARK: - Services
    private var snapshotService: any SnapshotService = MockSnapshotService()
    // Legacy services kept for potential Era/Gmail path
    private var financeService: any FinanceService = MockFinanceService()
    private var gmailService: any GmailService = MockGmailService()
    var liveGmail: LiveGmailService = LiveGmailService()

    // MARK: - VEGA sentinel
    private var sentinel: VegaSentinel?

    // MARK: - Tasks
    private var refreshTask: Task<Void, Never>? = nil
    private var retryTask: Task<Void, Never>? = nil
    private var retried = false

    // MARK: - Computed

    var threatLevel: ThreatLevel {
        if let snap = snapshot { return snap.resolvedThreatLevel }
        let checking = finance?.checkingBalance ?? 0
        let hasNewCritical = activeAlerts.contains { $0.severity == .critical && $0.isNew }
        let hasNewWarning  = activeAlerts.contains { $0.severity == .warning  && $0.isNew }
        if hasNewCritical || checking < lowBalanceThreshold { return .alert }
        if hasNewWarning { return .watch }
        return .allClear
    }

    var headline: String? { snapshot?.headline }

    var diagnostics: [String] {
        if let snap = snapshot { return snap.diagnostics ?? [] }
        return finance?.warnings ?? []
    }

    var activeAlerts: [MailAlert] {
        let dismissed = dismissedAlertIDs
        return alerts.filter { !dismissed.contains($0.id) }
    }

    var topLead: JobLead? {
        leads.filter { $0.isRecent }.max { $0.hourlyEquivalent < $1.hourlyEquivalent }
    }

    var eraConnectionState: ConnectionState  { snapshotState }
    var gmailConnectionState: ConnectionState { snapshotState }
    var feedConnectionState: ConnectionState  { snapshotState }

    var isSnapshotStale: Bool   { snapshot?.isStale ?? false }
    var snapshotFreshnessLabel: String { snapshot?.freshnessLabel ?? "—" }

    // MARK: - Init

    init() {
        if UserDefaults.standard.object(forKey: "use_sample_data") == nil {
            UserDefaults.standard.set(true, forKey: "use_sample_data")
        }
        loadCachedSnapshot()
        snapshotService = buildSnapshotService()
        sentinel = VegaSentinel(store: self)
        Task { await tryRestoreGmailSession() }
    }

    // MARK: - Refresh

    func refreshAll() async {
        retried = false
        log("Refresh started")
        await refreshFromSnapshot()
        if isGmailConnected && snapshot == nil {
            // Only fall back to direct Gmail when no snapshot is available
            await refreshFromGmail()
        }
        writeSnapshot()
        await updateMorningBrief()
        log("Refresh complete")
    }

    func refreshFromSnapshot() async {
        snapshotState = .loading
        do {
            let snap = try await snapshotService.fetch()
            snapshot = snap
            mapSnapshotToLegacy(snap)
            snapshotState = .connected
            let now = Date()
            snapshotRefreshedAt = now
            financeRefreshedAt  = now
            alertsRefreshedAt   = now
            leadsRefreshedAt    = now
            log("Snapshot loaded — generated \(snap.freshnessLabel)")
            await sentinel?.scan()
        } catch SnapshotError.notModified {
            snapshotState = .connected
            snapshotRefreshedAt = Date()
            log("Snapshot: no change (304)")
        } catch SnapshotError.schemaMismatch(let s) {
            snapshotState = .error("Feed format changed (\"\(s)\")")
            log("Snapshot: schema mismatch — \"\(s)\"")
            scheduleRetry()
        } catch ServiceError.unauthorized {
            snapshotState = .error("Check your feed token")
            log("Snapshot: 401/403")
        } catch {
            let nse = error as NSError
            let offline = nse.code == NSURLErrorNotConnectedToInternet ||
                          nse.code == NSURLErrorNetworkConnectionLost
            if offline {
                let label = snapshotRefreshedAt.map { d -> String in
                    let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
                } ?? "cached"
                snapshotState = .error("Offline · showing \(label) data")
                log("Snapshot: offline")
            } else {
                snapshotState = .error(error.localizedDescription)
                log("Snapshot error: \(error.localizedDescription)")
            }
            scheduleRetry()
        }
    }

    private func scheduleRetry() {
        guard !retried else { return }
        retried = true
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.refreshFromSnapshot()
        }
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 600_000_000_000) // 10 min
                guard !Task.isCancelled else { break }
                await self?.refreshAll()
            }
        }
    }

    func handleForeground() async {
        guard let last = snapshotRefreshedAt else { await refreshAll(); return }
        if Date().timeIntervalSince(last) > 300 { await refreshAll() }
    }

    func dismissAlert(id: String) {
        var set = dismissedAlertIDs
        set.insert(id)
        dismissedAlertIDs = set
    }

    func updateServices() {
        retryTask?.cancel()
        snapshotService = buildSnapshotService()
    }

    // MARK: - Cache

    private func loadCachedSnapshot() {
        guard let url = appGroupURL(for: "Snapshot.json"),
              let data = try? Data(contentsOf: url),
              let snap = try? HUDSnapshot.decoder.decode(HUDSnapshot.self, from: data),
              snap.isValid else { return }
        snapshot = snap
        mapSnapshotToLegacy(snap)
        log("Loaded cached snapshot (\(snap.freshnessLabel))")
    }

    private func writeSnapshot() {
        // Write full HUDSnapshot as Snapshot.json (cache + widget reads)
        if let snap = snapshot {
            let enc = JSONEncoder()
            enc.keyEncodingStrategy = .convertToSnakeCase
            enc.dateEncodingStrategy = .iso8601
            if let data = try? enc.encode(snap), let url = appGroupURL(for: "Snapshot.json") {
                try? data.write(to: url)
            }
        }
        // Write slim WidgetData.json for direct widget decoding
        let widget = WidgetData(
            checking:        snapshot?.funds?.checking       ?? finance?.checkingBalance ?? 0,
            cardOwed:        snapshot?.funds?.cardOwed       ?? finance?.cardBalance     ?? 0,
            threatLevel:     threatLevel,
            headline:        snapshot?.headline              ?? "",
            topLeadPayText:  topLead?.payTextOverride ?? topLead?.payDisplay,
            topLeadTitle:    topLead?.title,
            generatedAt:     snapshot?.generatedAt           ?? Date()
        )
        if let data = try? JSONEncoder().encode(widget), let url = appGroupURL(for: "WidgetData.json") {
            try? data.write(to: url)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func appGroupURL(for filename: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup)?
            .appendingPathComponent(filename)
    }

    // MARK: - Snapshot → legacy mapping

    private func mapSnapshotToLegacy(_ snap: HUDSnapshot) {
        if let f = snap.funds {
            var accounts: [Account] = []
            if let c = f.checking {
                accounts.append(Account(name: "Checking", institution: nil, type: "Checking",
                                        accountMask: nil, balance: Balance(current: c, currency: "USD")))
            }
            if let c = f.cardOwed {
                accounts.append(Account(name: "Card", institution: nil, type: "CreditCard",
                                        accountMask: nil, balance: Balance(current: c, currency: "USD")))
            }
            finance = FinanceOverview(
                accounts: accounts,
                netWorth: NetWorth(amount: f.netWorth, currencyCode: "USD"),
                currentMonth: f.currentMonth.map { m in
                    MonthSummary(label: m.label, income: AmountWrapper(amount: m.income),
                                 spending: AmountWrapper(amount: m.spending), net: AmountWrapper(amount: m.net))
                },
                lastMonth: f.lastMonth.map { m in
                    MonthSummary(label: m.label, income: AmountWrapper(amount: m.income),
                                 spending: AmountWrapper(amount: m.spending), net: AmountWrapper(amount: m.net))
                },
                topCategories: f.topCategories?.map { cat in
                    CategorySpend(category: cat.category,
                                  amount: AmountWrapper(amount: cat.amount),
                                  percentOfTotal: cat.percent)
                },
                warnings: snap.diagnostics,
                asOf: nil
            )
            if let t = f.lowThreshold { lowBalanceThreshold = t }
            financeState = .connected
        }

        let dismissed = dismissedAlertIDs
        alerts = (snap.alerts ?? []).map { a in
            MailAlert(
                id:                  a.id ?? UUID().uuidString,
                subject:             a.subject ?? "(no subject)",
                snippet:             a.snippet ?? "",
                sender:              a.sender ?? "",
                senderDomain:        Self.extractDomain(a.sender ?? ""),
                receivedAt:          a.receivedAt ?? snap.generatedAt ?? Date(),
                severity:            a.resolvedSeverity,
                classificationLabel: a.label ?? "",
                gmailLink:           a.url.flatMap { URL(string: $0) },
                dismissed:           dismissed.contains(a.id ?? "")
            )
        }.sorted { $0.receivedAt > $1.receivedAt }
        alertsState = .connected

        leads = (snap.leads ?? []).map { l in
            JobLead(
                id:              l.id ?? UUID().uuidString,
                messageId:       l.id ?? "",
                title:           l.title ?? "Untitled",
                role:            l.role,
                totalPay:        l.total ?? 0,
                payUnit:         "month",
                hoursOrDays:     nil,
                isDay:           false,
                hourlyEquivalent: l.hourly ?? 0,
                ageRange:        l.ageRange,
                location:        l.location,
                projectType:     l.kind,
                source:          LeadSource(rawValue: l.source ?? "") ?? .other,
                postedAgo:       l.posted,
                receivedAt:      snap.generatedAt ?? Date(),
                gmailLink:       l.url.flatMap { URL(string: $0) },
                payTextOverride: l.payText
            )
        }.sorted { $0.hourlyEquivalent > $1.hourlyEquivalent }
        leadsState = .connected
    }

    private static func extractDomain(_ sender: String) -> String {
        guard let at = sender.range(of: "@") else { return sender }
        return String(sender[at.upperBound...])
            .replacingOccurrences(of: ">", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Gmail connect / disconnect

    func connectGmail() async {
        do {
            let (token, email) = try await GoogleSignInManager.shared.signIn()
            await liveGmail.setAccessToken(token)
            isGmailConnected = true
            gmailUserEmail = email
            log("Gmail connected: \(email)")
        } catch {
            log("Gmail sign-in failed: \(error.localizedDescription)")
        }
    }

    func disconnectGmail() {
        GoogleSignInManager.shared.signOut()
        isGmailConnected = false
        gmailUserEmail = nil
        log("Gmail disconnected")
    }

    func tryRestoreGmailSession() async {
        guard let (token, email) = await GoogleSignInManager.shared.restoreSignIn() else { return }
        await liveGmail.setAccessToken(token)
        isGmailConnected = true
        gmailUserEmail = email
        log("Gmail session restored: \(email)")
    }

    private func refreshFromGmail() async {
        // Refresh the access token before fetching
        if let freshToken = try? await GoogleSignInManager.shared.freshToken() {
            await liveGmail.setAccessToken(freshToken)
        }
        do {
            let newAlerts = try await liveGmail.fetchAlerts()
            let newLeads  = try await liveGmail.fetchLeads()
            let existingIDs = Set(alerts.map(\.id))
            alerts += newAlerts.filter { !existingIDs.contains($0.id) }
            let existingLeadIDs = Set(leads.map(\.id))
            leads  += newLeads.filter  { !existingLeadIDs.contains($0.id) }
            alertsState = .connected
            leadsState  = .connected
            log("Gmail refresh complete — +\(newAlerts.count) alerts, +\(newLeads.count) leads")
        } catch ServiceError.unauthorized {
            isGmailConnected = false
            log("Gmail token expired — please reconnect")
        } catch {
            log("Gmail refresh error: \(error.localizedDescription)")
        }
    }

    // MARK: - Service factory

    private func buildSnapshotService() -> any SnapshotService {
        if useSampleData { return MockSnapshotService() }
        let url   = Keychain.get(Keychain.Keys.feedURL)   ?? ""
        let token = Keychain.get(Keychain.Keys.feedToken) ?? ""
        return RemoteSnapshotService(feedURL: url, feedToken: token)
    }

    // MARK: - Live Activity

    /// Start (or restart) a Morning Brief Live Activity. Safe to call from any view.
    func startMorningBrief() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for existing in Activity<MorningBriefAttributes>.activities {
            await existing.end(nil, dismissalPolicy: .immediate)
        }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 12; comps.minute = 0
        let noon = Calendar.current.date(from: comps) ?? Date()
        let staleDate = noon > Date() ? noon : Date().addingTimeInterval(4 * 3600)
        let attrs = MorningBriefAttributes(snapshotID: snapshot?.generatedAt.map { "\($0.timeIntervalSince1970)" } ?? UUID().uuidString)
        let content = ActivityContent(state: morningBriefState(), staleDate: staleDate)
        _ = try? Activity.request(attributes: attrs, content: content, pushType: nil)
    }

    /// Update all active Morning Brief Live Activities with current store data.
    func updateMorningBrief() async {
        let state = morningBriefState()
        for activity in Activity<MorningBriefAttributes>.activities {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func morningBriefState() -> MorningBriefAttributes.ContentState {
        MorningBriefAttributes.ContentState(
            threatLevel: threatLevel,
            headline: headline ?? "Morning HUD",
            checking: finance?.checkingBalance ?? 0,
            cardOwed: finance?.cardBalance ?? 0,
            topLeadTitle: topLead?.title,
            generatedAt: snapshot?.generatedAt ?? Date()
        )
    }

    // MARK: - Log

    func log(_ message: String) {
        let entry = LogEntry(timestamp: Date(), message: message)
        logEntries.insert(entry, at: 0)
        if logEntries.count > 40 { logEntries = Array(logEntries.prefix(40)) }
    }
}
