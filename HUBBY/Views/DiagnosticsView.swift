import SwiftUI

struct DiagnosticsView: View {
    @Environment(DashboardStore.self) private var store

    var body: some View {
        HUDFrame(index: "06", title: "Diagnostics") {
            VStack(alignment: .leading, spacing: 8) {
                if store.diagnostics.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.hudGreen)
                        Text("All systems nominal.")
                            .font(HUDFont.mono(12)).foregroundStyle(Color.hudGreen)
                    }
                } else {
                    ForEach(Array(store.diagnostics.enumerated()), id: \.offset) { _, warning in
                        HStack(alignment: .top, spacing: 8) {
                            Text(">").font(HUDFont.mono(11, weight: .medium)).foregroundStyle(Color.hudGold)
                            Text(warning).font(HUDFont.mono(11)).foregroundStyle(Color.hudGold)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
