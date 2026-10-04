import SwiftUI

struct DashboardView: View {
    @Environment(DashboardStore.self) private var store
    @Environment(VegaStore.self)      private var vega
    @State private var showSettings = false
    @State private var selectedTab  = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {

                // Tab 0 — native HUD panels
                HUDScrollView(showSettings: $showSettings)
                    .tabItem { Label("HUD", systemImage: "gauge.with.dots.needle.bottom.50percent") }
                    .tag(0)

                // Tab 1 — live WebView
                LiveHUDTab()
                    .tabItem { Label("LIVE", systemImage: "antenna.radiowaves.left.and.right") }
                    .tag(1)

                // Tab 2 — VEGA assistant (1.2 s boot sequence on first open)
                VegaTabWithLaunch()
                    .tabItem { Label("VEGA", systemImage: "waveform.circle.fill") }
                    .tag(2)
            }
            .toolbarBackground(Color.panel, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .onAppear { store.startAutoRefresh() }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onOpenURL { url in
                if GoogleSignInManager.shared.handle(url) { return }
                guard url.scheme == "morninghud" else { return }
                switch url.host() {
                case "live":        selectedTab = 1
                case "vega":        selectedTab = 2
                default:            selectedTab = 0
                }
                // morninghud://vega/listen — open VEGA and start listening
                if url.host() == "vega", url.pathComponents.contains("listen") {
                    selectedTab = 2
                    Task { @MainActor in vega.transition(to: .listening(level: 0)) }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .vegaBriefPlay)) { _ in
                selectedTab = 2
                // Small delay so the tab animation settles before VEGA starts speaking
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    vega.send("Read me today's brief")
                }
            }

            // Compact VEGA button — only visible on non-VEGA tabs
            if selectedTab != 2 {
                VegaCompactButton(
                    onTap:       { selectedTab = 2 },
                    onLongPress: {
                        selectedTab = 2
                        vega.transition(to: .listening(level: 0))
                    }
                )
                .padding(.trailing, 18)
                .padding(.bottom, 88) // sit above the tab bar
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selectedTab)
            }
        }
    }
}

// MARK: - Native HUD scroll view (tab 0)

private struct HUDScrollView: View {
    @Environment(DashboardStore.self) private var store
    @Binding var showSettings: Bool

    var body: some View {
        ZStack(alignment: .top) {
            HUDBackground()
            ScrollView {
                VStack(spacing: 0) {
                    TopRailView(
                        onRescan:   { await store.refreshAll() },
                        onSettings: { showSettings = true }
                    )
                    LazyVStack(spacing: 12) {
                        FundsView()
                        PriorityView()
                        CashFlowView()
                        ThreatScanView()
                        PaidLeadsView()
                        DiagnosticsView()
                        SystemLogView()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 32)
                }
            }
            .refreshable { await store.refreshAll() }
        }
        .task { await store.refreshAll() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await store.handleForeground() }
        }
    }
}

#Preview {
    DashboardView()
        .environment(DashboardStore())
        .environment(VegaStore())
}
