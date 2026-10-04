import SwiftUI

// MARK: - 60pt floating button shown on all non-VEGA tabs

struct VegaCompactButton: View {
    @Environment(VegaStore.self)      private var vega
    @Environment(DashboardStore.self) private var store

    let onTap:       () -> Void
    let onLongPress: () -> Void

    @State private var isPressed = false

    var body: some View {
        VegaCoreView(state: vega.state, diameter: 60)
            .background(
                Circle()
                    .fill(Color.panel.opacity(0.93))
            )
            .overlay(
                Circle()
                    .stroke(vega.state.primaryColor.opacity(0.30), lineWidth: 1)
            )
            // Critical-alert badge
            .overlay(alignment: .topTrailing) {
                if store.threatLevel == .alert {
                    Circle()
                        .fill(Color.hudRed)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.void, lineWidth: 1.5))
                        .offset(x: 3, y: -3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.threatLevel == .alert)
            .shadow(color: vega.state.primaryColor.opacity(0.30), radius: 10, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .onTapGesture { onTap() }
            .onLongPressGesture(minimumDuration: 0.35,
                                pressing: { active in isPressed = active },
                                perform:  { onLongPress() })
            .accessibilityLabel("VEGA assistant, \(vega.state.pillLabel.lowercased())\(store.threatLevel == .alert ? ", critical alert" : "")")
            .accessibilityHint("Tap to open. Hold to start talking.")
            .accessibilityAddTraits(.isButton)
    }
}
