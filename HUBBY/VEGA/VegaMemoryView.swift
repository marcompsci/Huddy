import SwiftUI

// MARK: - Memory list view (accessible from VEGA tab menu or Settings)

struct VegaMemoryView: View {
    @State private var manager = VegaMemoryManager.shared
    @State private var showForgetAlert = false

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            if manager.items.isEmpty {
                emptyState
            } else {
                memoryList
            }
        }
        .navigationTitle("VEGA Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Forget All") { showForgetAlert = true }
                    .font(HUDFont.mono(12))
                    .foregroundStyle(Color.hudRed)
            }
        }
        .alert("Forget everything?", isPresented: $showForgetAlert) {
            Button("Forget", role: .destructive) {
                Task { await manager.forgetEverything() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All VEGA memories will be permanently deleted.")
        }
        .task { await manager.fetch() }
        .preferredColorScheme(.dark)
    }

    private var memoryList: some View {
        List {
            ForEach(manager.items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.content)
                        .font(HUDFont.mono(12))
                        .foregroundStyle(Color.hudText)
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(HUDFont.mono(9))
                        .foregroundStyle(Color.faint)
                }
                .listRowBackground(Color.panel)
            }
            .onDelete { offsets in
                let ids = offsets.map { manager.items[$0].id }
                Task { for id in ids { await manager.delete(id: id) } }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.void)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "brain")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.faint)
            Text("No memories yet.")
                .font(HUDFont.mono(13))
                .foregroundStyle(Color.dim)
            Text("VEGA remembers facts you tell it to keep.")
                .font(HUDFont.mono(11))
                .foregroundStyle(Color.faint)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

#Preview {
    NavigationStack { VegaMemoryView() }
        .preferredColorScheme(.dark)
}
