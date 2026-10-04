import SwiftUI

// MARK: - Connected accounts + account management screen

struct VegaConnectedAccountsView: View {
    @Environment(DashboardStore.self) private var dashboard
    @State private var account = VegaAccountManager.shared
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            Form {

                // MARK: Account
                Section {
                    if account.isSignedIn {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.userName ?? "Apple User")
                                    .font(HUDFont.mono(13, weight: .medium))
                                    .foregroundStyle(Color.hudText)
                                if let email = account.userEmail {
                                    Text(email).font(HUDFont.mono(10)).foregroundStyle(Color.dim)
                                }
                            }
                            Spacer()
                            Button("Sign Out") { account.signOut() }
                                .font(HUDFont.mono(11))
                                .foregroundStyle(Color.hudRed)
                        }
                    } else {
                        VegaSignInButton()
                            .listRowBackground(Color.panel)
                    }
                } header: {
                    sectionHeader("ACCOUNT")
                }
                .listRowBackground(Color.panel)

                // MARK: Connected services
                Section {
                    // Gmail row
                    HStack {
                        Label("Gmail", systemImage: "envelope.circle")
                            .font(HUDFont.mono(13))
                            .foregroundStyle(Color.hudText)
                        Spacer()
                        if dashboard.isGmailConnected {
                            Text("Connected")
                                .font(HUDFont.mono(10))
                                .foregroundStyle(Color.hudGreen)
                        } else {
                            Text("Not connected")
                                .font(HUDFont.mono(10))
                                .foregroundStyle(Color.faint)
                        }
                    }

                    // Era row
                    HStack {
                        Label("Era Finance", systemImage: "chart.bar.xaxis")
                            .font(HUDFont.mono(13))
                            .foregroundStyle(Color.hudText)
                        Spacer()
                        Text("Legacy SDK")
                            .font(HUDFont.mono(10))
                            .foregroundStyle(Color.faint)
                    }
                } header: {
                    sectionHeader("CONNECTED SERVICES")
                }
                .listRowBackground(Color.panel)

                // MARK: Danger zone
                Section {
                    Button("Delete Account & All Data", role: .destructive) {
                        showDeleteAlert = true
                    }
                    .font(HUDFont.mono(13))
                } header: {
                    sectionHeader("DANGER ZONE")
                }
                .listRowBackground(Color.panel)
            }
            .scrollContentBackground(.hidden)
            .background(Color.void)
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Delete account?", isPresented: $showDeleteAlert) {
            Button("Delete Everything", role: .destructive) {
                Task { await account.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All conversations, memories and account data will be permanently deleted. This cannot be undone.")
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(HUDFont.mono(10)).foregroundStyle(Color.faint).kerning(1.5)
    }
}
