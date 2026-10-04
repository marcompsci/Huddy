import SwiftUI

// MARK: - 1.2 s boot animation shown on first launch of the VEGA tab

struct VegaLaunchSequence: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    @State private var phase: Int = 0

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()

            VStack(spacing: 20) {
                VegaCoreView(state: .thinking, diameter: 180)
                    .scaleEffect(phase >= 1 ? 1.0 : 0.6)
                    .opacity(phase >= 1 ? 1.0 : 0)

                VStack(spacing: 4) {
                    Text("VEGA")
                        .font(HUDFont.display(24, weight: .bold))
                        .foregroundStyle(Color.hudCyan)
                        .kerning(6)
                        .opacity(phase >= 2 ? 1 : 0)

                    Text("VOICE ASSISTANT")
                        .font(HUDFont.mono(11))
                        .foregroundStyle(Color.faint)
                        .kerning(3)
                        .opacity(phase >= 2 ? 1 : 0)
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: phase)
        .task {
            guard !reduceMotion else { onComplete(); return }
            phase = 1
            try? await Task.sleep(for: .milliseconds(400))
            phase = 2
            try? await Task.sleep(for: .milliseconds(800))
            onComplete()
        }
    }
}

// MARK: - Wrapper that gates VegaTab content behind the sequence

struct VegaTabWithLaunch: View {
    @State private var launched = UserDefaults.standard.bool(forKey: "vega.launched")

    var body: some View {
        if launched {
            VegaTab()
        } else {
            VegaLaunchSequence {
                UserDefaults.standard.set(true, forKey: "vega.launched")
                launched = true
            }
        }
    }
}
