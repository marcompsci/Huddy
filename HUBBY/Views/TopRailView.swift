import SwiftUI

struct TopRailView: View {
    @Environment(DashboardStore.self) private var store
    @State private var now = Date()
    let onRescan: () async -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DAILY OPS · BALANCE & SIGNAL")
                .font(HUDFont.mono(9))
                .foregroundStyle(Color.faint)
                .kerning(1.5)

            HStack(alignment: .center, spacing: 0) {
                HStack(spacing: 4) {
                    Text("OMARI")
                        .font(HUDFont.display(18, weight: .bold))
                        .foregroundStyle(Color.hudText)
                    Text("//")
                        .font(HUDFont.display(18, weight: .bold))
                        .foregroundStyle(Color.hudGold)
                    Text("MORNING HUD")
                        .font(HUDFont.display(18, weight: .bold))
                        .foregroundStyle(Color.hudText)
                }

                Spacer()

                HStack(spacing: 10) {
                    LinkLight(label: "FEED", state: store.feedConnectionState.dot)
                    Text(clockString)
                        .font(HUDFont.mono(12, weight: .medium))
                        .foregroundStyle(Color.hudCyan)
                        .monospacedDigit()
                    Button {
                        Task { await onRescan() }
                    } label: {
                        Text("RESCAN")
                            .font(HUDFont.mono(10, weight: .medium))
                            .foregroundStyle(Color.hudCyan)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.lineHot.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.cyanDim, lineWidth: 1))
                    }
                    Button(action: onSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.dim)
                    }
                }
            }

            // Staleness chip — shown when snapshot is > 26 hours old
            if store.isSnapshotStale, store.snapshot != nil {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.hudGold)
                    Text("STALE · last sync \(store.snapshotFreshnessLabel)")
                        .font(HUDFont.mono(10))
                        .foregroundStyle(Color.hudGold)
                    Spacer()
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.goldDim.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.hudGold.opacity(0.4), lineWidth: 1))
            }

            // Sample data badge
            if store.useSampleData {
                HStack(spacing: 6) {
                    Text("SAMPLE DATA")
                        .font(HUDFont.mono(9, weight: .medium))
                        .foregroundStyle(Color.hudGold)
                        .kerning(1)
                    Spacer()
                    Text("Connect a live feed in Settings")
                        .font(HUDFont.mono(9))
                        .foregroundStyle(Color.dim)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.goldDim.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private var clockString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: now)
    }
}

struct LinkLight: View {
    let label: String
    let state: DotState
    @State private var blinkOn = true

    var dotColor: Color {
        switch state {
        case .connected: return .hudGreen
        case .loading:   return blinkOn ? .hudGold : .clear
        case .error:     return .hudRed
        case .idle:      return .dim
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .shadow(color: dotColor.opacity(0.8), radius: state == .connected ? 3 : 0)
            Text(label)
                .font(HUDFont.mono(8))
                .foregroundStyle(Color.dim)
        }
        .onChange(of: state) { _, new in
            if new == .loading {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) { blinkOn.toggle() }
            }
        }
        .onAppear {
            if state == .loading {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) { blinkOn.toggle() }
            }
        }
    }
}
