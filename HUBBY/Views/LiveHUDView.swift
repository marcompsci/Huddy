import SwiftUI
import WebKit
import SafariServices

// MARK: - Tab wrapper

struct LiveHUDTab: View {
    @State private var progress: Double = 0
    @State private var isLoading = false
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var showHint: Bool
    @State private var loadTrigger = UUID()
    @State private var lastLoadTime: Date? = nil

    init() {
        _showHint = State(initialValue: !UserDefaults.standard.bool(forKey: "live_hud_hint_dismissed"))
    }

    private var hudURL: URL {
        let fallback = "https://claude.ai/artifact/FxSvHAMAjsZ494vze3726y"
        let stored = UserDefaults.standard.string(forKey: "live_hud_url") ?? fallback
        return URL(string: stored) ?? URL(string: fallback)!
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.void.ignoresSafeArea()
            VStack(spacing: 0) {
                if showHint {
                    SignInHintBanner {
                        UserDefaults.standard.set(true, forKey: "live_hud_hint_dismissed")
                        withAnimation(.easeOut(duration: 0.25)) { showHint = false }
                    }
                }

                // Thin cyan progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Color.void.frame(height: 2)
                        if isLoading {
                            Color.hudCyan
                                .frame(width: geo.size.width * CGFloat(progress), height: 2)
                                .animation(.easeInOut(duration: 0.15), value: progress)
                        }
                    }
                }
                .frame(height: 2)

                ZStack {
                    LiveHUDWebView(
                        url: hudURL,
                        loadTrigger: loadTrigger,
                        progress: $progress,
                        isLoading: $isLoading,
                        hasError: $hasError,
                        errorMessage: $errorMessage,
                        onLoaded: { lastLoadTime = Date() }
                    )
                    if hasError {
                        WebErrorOverlay(message: errorMessage) {
                            hasError = false
                            loadTrigger = UUID()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard let last = lastLoadTime, Date().timeIntervalSince(last) > 300 else { return }
            loadTrigger = UUID()
        }
    }
}

// MARK: - UIViewRepresentable

struct LiveHUDWebView: UIViewRepresentable {
    let url: URL
    let loadTrigger: UUID
    @Binding var progress: Double
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var errorMessage: String
    var onLoaded: () -> Void

    private static let allowedHosts: [String] = [
        "claude.ai", "claudeusercontent.com", "anthropic.com"
    ]

    static func isAllowed(_ host: String?) -> Bool {
        guard let h = host?.lowercased() else { return false }
        return allowedHosts.contains { h == $0 || h.hasSuffix("." + $0) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.backgroundColor = UIColor(red: 5/255, green: 9/255, blue: 14/255, alpha: 1)
        wv.isOpaque = false
        wv.scrollView.backgroundColor = .clear
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
#if DEBUG
        wv.isInspectable = true
#endif
        let refresh = UIRefreshControl()
        refresh.tintColor = UIColor(red: 95/255, green: 227/255, blue: 255/255, alpha: 1)
        refresh.addTarget(context.coordinator,
                          action: #selector(Coordinator.handleRefresh(_:)),
                          for: .valueChanged)
        wv.scrollView.refreshControl = refresh

        context.coordinator.webView = wv
        context.coordinator.startObserving(wv)
        context.coordinator.lastLoadTrigger = loadTrigger
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.lastLoadTrigger != loadTrigger {
            context.coordinator.lastLoadTrigger = loadTrigger
            wv.load(URLRequest(url: url))
        }
    }
}

// MARK: - Coordinator

extension LiveHUDWebView {
    @MainActor
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: LiveHUDWebView
        weak var webView: WKWebView?
        var observation: NSKeyValueObservation?
        var lastLoadTrigger: UUID = UUID()

        init(parent: LiveHUDWebView) { self.parent = parent }

        func startObserving(_ wv: WKWebView) {
            observation = wv.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                Task { @MainActor [weak self] in self?.parent.progress = wv.estimatedProgress }
            }
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            webView?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { sender.endRefreshing() }
        }

        // MARK: Navigation policy

        func webView(_ wv: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { decisionHandler(.allow); return }
            let host = url.host?.lowercased() ?? ""

            if LiveHUDWebView.isAllowed(host) { decisionHandler(.allow); return }

            if host.contains("mail.google.com") {
                let gmailScheme = URL(string: "googlegmail://")!
                if UIApplication.shared.canOpenURL(gmailScheme) {
                    UIApplication.shared.open(url)
                } else {
                    openExternally(url)
                }
                decisionHandler(.cancel)
                return
            }

            openExternally(url)
            decisionHandler(.cancel)
        }

        // target=_blank
        func webView(_ wv: WKWebView,
                     createWebViewWith config: WKWebViewConfiguration,
                     for action: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let url = action.request.url else { return nil }
            if LiveHUDWebView.isAllowed(url.host) {
                wv.load(action.request)
            } else {
                openExternally(url)
            }
            return nil
        }

        func webView(_ wv: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            parent.isLoading = true
            parent.hasError = false
        }

        func webView(_ wv: WKWebView, didFinish _: WKNavigation!) {
            parent.isLoading = false
            parent.progress = 1.0
            parent.onLoaded()
            wv.scrollView.refreshControl?.endRefreshing()
        }

        func webView(_ wv: WKWebView, didFail _: WKNavigation!, withError e: Error) { handleError(e) }
        func webView(_ wv: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError e: Error) { handleError(e) }

        private func handleError(_ error: Error) {
            parent.isLoading = false
            parent.hasError = true
            let nse = error as NSError
            parent.errorMessage = (nse.code == NSURLErrorNotConnectedToInternet ||
                                   nse.code == NSURLErrorNetworkConnectionLost)
                ? "No connection" : error.localizedDescription
        }

        private func openExternally(_ url: URL) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else {
                UIApplication.shared.open(url)
                return
            }
            let safari = SFSafariViewController(url: url)
            safari.preferredBarTintColor = UIColor(red: 5/255, green: 9/255, blue: 14/255, alpha: 1)
            root.present(safari, animated: true)
        }
    }
}

// MARK: - Sign-in hint banner

struct SignInHintBanner: View {
    let onDismiss: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(Color.hudCyan).font(.system(size: 14))
            Text("Sign in to claude.ai with your email code. Google sign-in is blocked inside in-app browsers.")
                .font(HUDFont.mono(11))
                .foregroundStyle(Color.hudText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Got it", action: onDismiss)
                .font(HUDFont.mono(11, weight: .medium))
                .foregroundStyle(Color.hudGold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.panel2)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.line), alignment: .bottom)
    }
}

// MARK: - Error overlay

struct WebErrorOverlay: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        ZStack {
            Color.void.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.hudRed)
                Text(message.uppercased())
                    .font(HUDFont.mono(12))
                    .foregroundStyle(Color.hudText)
                    .multilineTextAlignment(.center)
                Button(action: onRetry) {
                    Text("RETRY")
                        .font(HUDFont.mono(13, weight: .medium))
                        .foregroundStyle(Color.void)
                        .padding(.horizontal, 28).padding(.vertical, 10)
                        .background(Color.hudRed)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}
