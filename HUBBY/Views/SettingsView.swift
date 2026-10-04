import SwiftUI

struct SettingsView: View {
    @Environment(DashboardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    // Feed settings
    @State private var feedURL: String   = Keychain.get(Keychain.Keys.feedURL)   ?? ""
    @State private var feedToken: String = Keychain.get(Keychain.Keys.feedToken) ?? ""
    @State private var feedTestResult: String? = nil
    @State private var isFeedTesting = false

    // Live HUD URL
    @State private var liveHUDURL: String = UserDefaults.standard.string(forKey: "live_hud_url")
        ?? "https://claude.ai/artifact/FxSvHAMAjsZ494vze3726y"

    // Era settings (legacy)
    @State private var eraBaseURL:      String = Keychain.get(Keychain.Keys.eraBaseURL)      ?? ""
    @State private var eraEndpointPath: String = Keychain.get(Keychain.Keys.eraEndpointPath) ?? "/context/financial"
    @State private var eraAPIKey:       String = Keychain.get(Keychain.Keys.eraAPIKey)       ?? ""

    // VEGA backend
    @State private var vegaBackendURL:   String = Keychain.get(Keychain.Keys.vegaBackendURL)   ?? ""
    @State private var vegaSessionToken: String = Keychain.get(Keychain.Keys.vegaSessionToken) ?? ""
    @State private var vegaTestResult:   String? = nil
    @State private var isVegaTesting             = false

    // VEGA personality (non-secrets, stored in UserDefaults via VegaPersonality)
    @State private var vegaAssistantName: String = VegaPersonality.shared.assistantName
    @State private var vegaCallMeName:    String = VegaPersonality.shared.callMeName
    @State private var vegaVerbosity:     VegaPersonality.Verbosity = VegaPersonality.shared.verbosity

    @State private var lowBalanceThreshold: String = ""
    @State private var gmailThreatQuery: String = GmailQueries.threatScan
    @State private var gmailLeadQuery:   String = GmailQueries.leadScan
    @State private var isConnectingGmail = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.void.ignoresSafeArea()
                Form {

                    // MARK: Data source
                    Section {
                        Picker("Data Source", selection: Binding(
                            get: { store.useSampleData ? "sample" : "feed" },
                            set: { store.useSampleData = $0 == "sample"; store.updateServices() }
                        )) {
                            Text("Live Feed").tag("feed")
                            Text("Sample Data").tag("sample")
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.panel)
                    } header: {
                        sectionHeader("DATA SOURCE")
                    }
                    .listRowBackground(Color.panel)

                    // MARK: Snapshot feed
                    Section {
                        HUDTextField(label: "Feed URL", text: $feedURL,
                                     placeholder: "https://your-feed.example.com/morninghud.json")
                        HUDSecureField(label: "Feed Token (optional)", text: $feedToken)

                        HStack(spacing: 12) {
                            Button(isFeedTesting ? "Testing…" : "Test Feed") {
                                Task { await testFeed() }
                            }
                            .disabled(isFeedTesting || feedURL.isEmpty)
                            .foregroundStyle(Color.hudCyan)
                            .font(HUDFont.mono(12))

                            Button("Clear Cache") { clearCache() }
                                .foregroundStyle(Color.dim)
                                .font(HUDFont.mono(12))
                        }

                        if let result = feedTestResult {
                            Text(result)
                                .font(HUDFont.mono(11))
                                .foregroundStyle(result.hasPrefix("✓") ? Color.hudGreen : Color.hudRed)
                        }
                    } header: {
                        sectionHeader("SNAPSHOT FEED")
                    }
                    .listRowBackground(Color.panel)

                    // MARK: Live HUD
                    Section {
                        HUDTextField(label: "Artifact URL", text: $liveHUDURL,
                                     placeholder: "https://claude.ai/artifact/...")
                    } header: {
                        sectionHeader("LIVE HUD URL")
                    }
                    .listRowBackground(Color.panel)

                    // MARK: Gmail
                    Section {
                        if store.isGmailConnected, let email = store.gmailUserEmail {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.hudGreen)
                                Text(email)
                                    .font(HUDFont.mono(12))
                                    .foregroundStyle(Color.hudText)
                                Spacer()
                                Button("Disconnect") {
                                    store.disconnectGmail()
                                }
                                .font(HUDFont.mono(11))
                                .foregroundStyle(Color.hudRed)
                            }
                        } else {
                            Button {
                                isConnectingGmail = true
                                Task {
                                    await store.connectGmail()
                                    isConnectingGmail = false
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if isConnectingGmail {
                                        ProgressView().tint(Color.hudCyan)
                                    } else {
                                        Image(systemName: "envelope.badge.shield.half.filled")
                                    }
                                    Text(isConnectingGmail ? "Signing in…" : "Connect Gmail")
                                }
                                .font(HUDFont.mono(13, weight: .medium))
                                .foregroundStyle(Color.hudCyan)
                            }
                            .disabled(isConnectingGmail)
                        }
                    } header: {
                        sectionHeader("GMAIL")
                    } footer: {
                        Text("Read-only. Used to scan alerts and leads directly when no snapshot feed is configured.")
                            .font(HUDFont.mono(10))
                            .foregroundStyle(Color.faint)
                    }
                    .listRowBackground(Color.panel)

                    // MARK: Thresholds
                    Section {
                        HUDTextField(label: "Low Balance Alert ($)", text: $lowBalanceThreshold,
                                     placeholder: "100", keyboardType: .decimalPad)
                    } header: {
                        sectionHeader("THRESHOLDS")
                    }
                    .listRowBackground(Color.panel)

                    // MARK: Gmail (legacy queries)
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Threat Scan").font(HUDFont.mono(10)).foregroundStyle(Color.faint)
                            TextEditor(text: $gmailThreatQuery)
                                .font(HUDFont.mono(11)).foregroundStyle(Color.hudText)
                                .frame(height: 60).background(Color.panel2).scrollContentBackground(.hidden)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lead Scan").font(HUDFont.mono(10)).foregroundStyle(Color.faint)
                            TextEditor(text: $gmailLeadQuery)
                                .font(HUDFont.mono(11)).foregroundStyle(Color.hudText)
                                .frame(height: 50).background(Color.panel2).scrollContentBackground(.hidden)
                        }
                    } header: {
                        sectionHeader("GMAIL QUERIES")
                    }
                    .listRowBackground(Color.panel)

                    // MARK: Era (legacy)
                    Section {
                        HUDTextField(label: "Base URL",      text: $eraBaseURL,      placeholder: "https://…")
                        HUDTextField(label: "Endpoint Path", text: $eraEndpointPath,  placeholder: "/context/financial")
                        HUDSecureField(label: "API Key",     text: $eraAPIKey)
                    } header: {
                        sectionHeader("ERA CONTEXT (LEGACY)")
                    }
                    .listRowBackground(Color.panel)

                    // MARK: VEGA backend
                    Section {
                        HUDTextField(label: "Backend URL", text: $vegaBackendURL,
                                     placeholder: "https://api.yourserver.com")
                            .onChange(of: vegaBackendURL) { _, _ in vegaTestResult = nil }
                        HUDSecureField(label: "Session Token", text: $vegaSessionToken)

                        HStack(spacing: 12) {
                            Button(isVegaTesting ? "Testing…" : "Test Backend") {
                                Task { await testVegaBackend() }
                            }
                            .disabled(isVegaTesting || vegaBackendURL.isEmpty)
                            .foregroundStyle(Color.hudCyan)
                            .font(HUDFont.mono(12))
                        }

                        if let result = vegaTestResult {
                            Text(result)
                                .font(HUDFont.mono(11))
                                .foregroundStyle(result.hasPrefix("✓") ? Color.hudGreen : Color.hudRed)
                        }
                    } header: {
                        sectionHeader("VEGA BACKEND")
                    } footer: {
                        Text("Session token is stored in the Keychain. The app never sends this to any third party.")
                            .font(HUDFont.mono(10))
                            .foregroundStyle(Color.faint)
                    }
                    .listRowBackground(Color.panel)

                    // MARK: VEGA persona
                    Section {
                        HUDTextField(label: "Assistant Name", text: $vegaAssistantName,
                                     placeholder: "VEGA")
                        HUDTextField(label: "Call Me", text: $vegaCallMeName,
                                     placeholder: "Optional — your name")
                        Picker("Verbosity", selection: $vegaVerbosity) {
                            ForEach(VegaPersonality.Verbosity.allCases, id: \.self) { v in
                                Text(v.label).tag(v)
                            }
                        }
                        .font(HUDFont.mono(12))
                        .foregroundStyle(Color.hudText)
                    } header: {
                        sectionHeader("VEGA PERSONA")
                    }
                    .listRowBackground(Color.panel)

                    // MARK: VEGA account + memory
                    Section {
                        NavigationLink {
                            VegaConnectedAccountsView()
                        } label: {
                            Label("Account & Services", systemImage: "person.crop.circle")
                                .font(HUDFont.mono(13))
                                .foregroundStyle(Color.hudText)
                        }
                        NavigationLink {
                            VegaMemoryView()
                        } label: {
                            Label("Memory", systemImage: "brain")
                                .font(HUDFont.mono(13))
                                .foregroundStyle(Color.hudText)
                        }
                    } header: {
                        sectionHeader("VEGA ACCOUNT")
                    }
                    .listRowBackground(Color.panel)
                }
                .scrollContentBackground(.hidden)
                .background(Color.void)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveAndDismiss() }
                        .foregroundStyle(Color.hudCyan)
                        .font(HUDFont.mono(13, weight: .medium))
                }
            }
            .onAppear {
                lowBalanceThreshold = "\(Int(store.lowBalanceThreshold))"
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        Keychain.set(feedURL,   key: Keychain.Keys.feedURL)
        Keychain.set(feedToken, key: Keychain.Keys.feedToken)
        UserDefaults.standard.set(liveHUDURL, forKey: "live_hud_url")
        Keychain.set(eraBaseURL,      key: Keychain.Keys.eraBaseURL)
        Keychain.set(eraEndpointPath, key: Keychain.Keys.eraEndpointPath)
        Keychain.set(eraAPIKey,       key: Keychain.Keys.eraAPIKey)
        // VEGA backend (Keychain)
        Keychain.set(vegaBackendURL,   key: Keychain.Keys.vegaBackendURL)
        Keychain.set(vegaSessionToken, key: Keychain.Keys.vegaSessionToken)
        // VEGA persona (UserDefaults via VegaPersonality)
        VegaPersonality.shared.assistantName = vegaAssistantName
        VegaPersonality.shared.callMeName    = vegaCallMeName
        VegaPersonality.shared.verbosity     = vegaVerbosity
        VegaPersonality.shared.save()
        if let t = Double(lowBalanceThreshold) { store.lowBalanceThreshold = t }
        store.updateServices()
        dismiss()
    }

    private func testFeed() async {
        isFeedTesting = true
        feedTestResult = nil
        let svc = RemoteSnapshotService(feedURL: feedURL, feedToken: feedToken)
        do {
            let snap = try await svc.fetch()
            let gen  = snap.freshnessLabel
            feedTestResult = "✓ HTTP 200 · schema \"\(snap.schema ?? "?")\" · generated \(gen)"
        } catch SnapshotError.schemaMismatch(let s) {
            feedTestResult = "✗ Schema mismatch: got \"\(s)\""
        } catch SnapshotError.notModified {
            feedTestResult = "✓ HTTP 304 — no change"
        } catch {
            feedTestResult = "✗ \(error.localizedDescription)"
        }
        isFeedTesting = false
    }

    private func testVegaBackend() async {
        isVegaTesting = true
        vegaTestResult = nil
        let raw = vegaBackendURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let url = URL(string: raw)?.appendingPathComponent("v1/session") else {
            vegaTestResult = "✗ Invalid URL"
            isVegaTesting = false
            return
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.httpMethod = "GET"
        let token = vegaSessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                vegaTestResult = http.statusCode < 500
                    ? "✓ Server reachable (HTTP \(http.statusCode))"
                    : "✗ Server error (HTTP \(http.statusCode))"
            } else {
                vegaTestResult = "✗ Unexpected response type"
            }
        } catch {
            vegaTestResult = "✗ \(error.localizedDescription)"
        }
        isVegaTesting = false
    }

    private func clearCache() {
        let groupID = "group.com.omari.morninghud"
        if let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            try? FileManager.default.removeItem(at: base.appendingPathComponent("Snapshot.json"))
            try? FileManager.default.removeItem(at: base.appendingPathComponent("WidgetData.json"))
        }
        store.log("Cache cleared")
        feedTestResult = "✓ Cache cleared"
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(HUDFont.mono(10)).foregroundStyle(Color.faint).kerning(1.5)
    }
}

// MARK: - Reusable form fields

struct HUDTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(HUDFont.mono(10)).foregroundStyle(Color.faint)
            TextField(placeholder, text: $text)
                .font(HUDFont.mono(12)).foregroundStyle(Color.hudText)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}

struct HUDSecureField: View {
    let label: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(HUDFont.mono(10)).foregroundStyle(Color.faint)
            SecureField("••••••••", text: $text)
                .font(HUDFont.mono(12)).foregroundStyle(Color.hudText)
        }
    }
}
