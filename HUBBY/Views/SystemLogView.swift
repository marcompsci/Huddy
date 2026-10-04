import SwiftUI

struct SystemLogView: View {
    @Environment(DashboardStore.self) private var store

    var body: some View {
        HUDFrame(index: "07", title: "System Log") {
            VStack(alignment: .leading, spacing: 2) {
                if store.logEntries.isEmpty {
                    Text("// no events yet")
                        .font(HUDFont.mono(11))
                        .foregroundStyle(Color.faint)
                } else {
                    ForEach(store.logEntries) { entry in
                        Text(entry.formatted)
                            .font(HUDFont.mono(11))
                            .foregroundStyle(Color.dim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
