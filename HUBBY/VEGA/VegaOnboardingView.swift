import SwiftUI
import UserNotifications

// MARK: - 3-page first-launch onboarding

struct VegaOnboardingView: View {
    var onComplete: () -> Void

    @State private var page       = 0
    @State private var backendURL = Keychain.get(Keychain.Keys.vegaBackendURL) ?? ""
    @State private var testResult: ConnectionResult? = nil
    @State private var isTesting  = false

    private enum ConnectionResult { case ok, fail }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.void.ignoresSafeArea()
            TabView(selection: $page) {
                welcomePage.tag(0)
                signInPage.tag(1)
                backendPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: page)

            pageIndicator
                .padding(.bottom, 20)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Dot indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i == page ? Color.hudCyan : Color.faint)
                    .frame(width: i == page ? 8 : 5, height: i == page ? 8 : 5)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: page)
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()
            VegaCoreView(state: .idle, diameter: 120)
                .background(Circle().fill(Color.panel.opacity(0.9)))
                .overlay(Circle().stroke(Color.hudCyan.opacity(0.25), lineWidth: 1))
                .shadow(color: Color.hudCyan.opacity(0.25), radius: 24)
                .padding(.bottom, 36)

            Text("VEGA")
                .font(HUDFont.display(40))
                .foregroundStyle(Color.hudCyan)
                .tracking(8)
                .padding(.bottom, 12)

            Text("Your personal financial intelligence.")
                .font(HUDFont.mono(13))
                .foregroundStyle(Color.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            Spacer()

            primaryButton("Get Started") { page = 1 }
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            ghostButton("Skip setup") { finish() }
                .padding(.bottom, 52)
        }
    }

    // MARK: - Page 2: Sign In

    private var signInPage: some View {
        VStack(spacing: 0) {
            Spacer()
            pageTitle(
                "Connect Your Account",
                subtitle: "Sign in to enable VEGA memory,\npersonalised briefs, and history sync."
            )
            .padding(.bottom, 40)

            VegaSignInButton()
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            ghostButton("Continue without account") { page = 2 }
            Spacer()
            Spacer().frame(height: 52)
        }
        .onChange(of: VegaAccountManager.shared.isSignedIn) { _, signedIn in
            if signedIn { page = 2 }
        }
    }

    // MARK: - Page 3: Backend URL

    private var backendPage: some View {
        VStack(spacing: 0) {
            Spacer()
            pageTitle(
                "Connect Backend",
                subtitle: "Point VEGA to your server for\nlive AI chat and intelligence."
            )
            .padding(.bottom, 32)

            VStack(spacing: 10) {
                TextField("https://api.example.com", text: $backendURL)
                    .font(HUDFont.mono(13))
                    .foregroundStyle(Color.hudText)
                    .tint(Color.hudCyan)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(urlBorderColor, lineWidth: 1)
                    )
                    .onChange(of: backendURL) { _, _ in testResult = nil }

                HStack {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack(spacing: 6) {
                            if isTesting {
                                ProgressView().scaleEffect(0.7).tint(Color.hudCyan)
                            } else {
                                Image(systemName: testIconName)
                                    .foregroundStyle(testIconColor)
                            }
                            Text(testLabel)
                                .font(HUDFont.mono(11))
                                .foregroundStyle(isTesting ? Color.faint : Color.hudText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(backendURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)
                    Spacer()
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            primaryButton("Done") { finish() }
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            ghostButton("Skip for now") { finish() }
                .padding(.bottom, 52)
        }
    }

    // MARK: - Connection test

    @MainActor
    private func testConnection() async {
        let raw = backendURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let url = URL(string: raw)?.appendingPathComponent("v1/session") else {
            testResult = .fail; return
        }
        isTesting = true
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.httpMethod = "GET"
        if let token = Keychain.get(Keychain.Keys.vegaSessionToken), !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var statusOK = false
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse {
            statusOK = http.statusCode < 500
        }
        isTesting  = false
        testResult = statusOK ? .ok : .fail
    }

    // MARK: - Complete onboarding

    @MainActor
    private func finish() {
        let raw = backendURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty { Keychain.set(raw, key: Keychain.Keys.vegaBackendURL) }
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        }
        onComplete()
    }

    // MARK: - Computed helpers

    private var urlBorderColor: Color {
        switch testResult {
        case .ok:   Color.hudCyan.opacity(0.5)
        case .fail: Color.hudRed.opacity(0.5)
        case nil:   Color.line
        }
    }

    private var testLabel: String {
        if isTesting { return "Testing…" }
        switch testResult {
        case .ok:   return "Connected"
        case .fail: return "Unreachable"
        case nil:   return "Test Connection"
        }
    }

    private var testIconName: String {
        switch testResult {
        case .ok:   "checkmark.circle.fill"
        case .fail: "xmark.circle.fill"
        case nil:   "network"
        }
    }

    private var testIconColor: Color {
        switch testResult {
        case .ok:   Color.hudCyan
        case .fail: Color.hudRed
        case nil:   Color.faint
        }
    }

    // MARK: - Sub-components

    private func pageTitle(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(HUDFont.display(22))
                .foregroundStyle(Color.hudText)
                .tracking(1)
            Text(subtitle)
                .font(HUDFont.mono(12))
                .foregroundStyle(Color.dim)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private func primaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(HUDFont.mono(14, weight: .medium))
                .foregroundStyle(Color.void)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.hudCyan)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func ghostButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(HUDFont.mono(11))
                .foregroundStyle(Color.faint)
                .padding(.vertical, 8)
        }
    }
}
