import SwiftUI

struct HUDBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweepOffset: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.void.ignoresSafeArea()

                // Radial glow top-left (cyan)
                RadialGradient(
                    colors: [Color.hudCyan.opacity(0.07), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.9
                )
                .ignoresSafeArea()

                // Radial glow top-right (gold)
                RadialGradient(
                    colors: [Color.hudGold.opacity(0.05), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.8
                )
                .ignoresSafeArea()

                // Horizontal scanlines
                Canvas { ctx, size in
                    var y: CGFloat = 0
                    while y < size.height {
                        let path = Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        ctx.stroke(path, with: .color(Color.hudCyan.opacity(0.025)), lineWidth: 1)
                        y += 4
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Vertical light sweep
                if !reduceMotion {
                    LinearGradient(
                        colors: [.clear, Color.hudCyan.opacity(0.04), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.3)
                    .offset(x: sweepOffset * geo.size.width * 1.6 - geo.size.width * 0.3)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            sweepOffset = -0.1
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                sweepOffset = 1.1
            }
        }
    }
}
