import SwiftUI

struct FundsView: View {
    @Environment(DashboardStore.self) private var store

    private var checking: Double { store.finance?.checkingBalance ?? 0 }
    private var card: Double { store.finance?.cardBalance ?? 0 }
    private var total: Double { max(checking + card, 1) }
    private var isSample: Bool { store.useSampleData }
    private var threshold: Double { store.lowBalanceThreshold }

    private var refreshLabel: String {
        guard let d = store.financeRefreshedAt else { return "" }
        let mins = Int(Date().timeIntervalSince(d) / 60)
        return mins < 1 ? "Read just now" : "Read \(mins)m ago"
    }

    var body: some View {
        HUDFrame(index: "01", title: "Funds Core",
                 timestamp: refreshLabel,
                 isAlert: checking < threshold) {
            VStack(spacing: 16) {
                if isSample {
                    SampleBadge()
                }
                FundsGauge(checking: checking, card: card, threshold: threshold)
                    .frame(width: 300, height: 300)

                // Legend
                HStack(spacing: 24) {
                    LegendItem(color: .hudGold, label: "Checking")
                    LegendItem(color: .hudRed, label: "Card owed")
                }

                if card > 0 {
                    let ratio = (checking / max(card, 0.01))
                    Text("Checking covers card \(String(format: "%.1f", ratio))×")
                        .font(HUDFont.mono(11))
                        .foregroundStyle(ratio < 1 ? Color.hudRed : Color.hudGreen)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 4)
            Text(label).font(HUDFont.mono(11)).foregroundStyle(Color.dim)
        }
    }
}

// MARK: - Circular gauge

struct FundsGauge: View {
    let checking: Double
    let card: Double
    let threshold: Double

    @State private var animateArcs: Bool = false
    @State private var outerRotation: Double = 0
    @State private var innerRotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var total: Double { max(checking + card, 1) }
    private var checkingAngle: Double { (checking / total) * 270 }
    private var cardAngle: Double { (card / total) * 270 }
    private var isLow: Bool { checking < threshold }

    var body: some View {
        ZStack {
            // Tick marks ring (outer)
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let r: CGFloat = size.width / 2 - 8
                for i in 0..<72 {
                    let angle = Double(i) * (360.0 / 72.0)
                    let rad = angle * .pi / 180
                    let isLong = i % 6 == 0
                    let len: CGFloat = isLong ? 10 : 5
                    let outer = CGPoint(x: center.x + cos(rad) * r, y: center.y + sin(rad) * r)
                    let inner = CGPoint(x: center.x + cos(rad) * (r - len), y: center.y + sin(rad) * (r - len))
                    var path = Path()
                    path.move(to: inner)
                    path.addLine(to: outer)
                    ctx.stroke(path, with: .color(isLong ? Color.hudCyan : Color.line), lineWidth: isLong ? 1.5 : 0.8)
                }
            }
            .rotationEffect(.degrees(outerRotation))

            // Track ring
            Circle()
                .stroke(Color.line, lineWidth: 10)
                .padding(20)

            // Checking arc (gold)
            Circle()
                .trim(from: 0, to: animateArcs ? CGFloat(checkingAngle / 360) : 0)
                .stroke(Color.hudGold, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .padding(20)
                .rotationEffect(.degrees(-135))

            // Card arc (red)
            Circle()
                .trim(from: 0, to: animateArcs ? CGFloat(cardAngle / 360) : 0)
                .stroke(Color.hudRed, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .padding(20)
                .rotationEffect(.degrees(-135 + checkingAngle))

            // Inner dashed ring
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
                .foregroundStyle(Color.cyanDim.opacity(0.5))
                .padding(46)
                .rotationEffect(.degrees(innerRotation))
                .overlay(
                    // Two short cyan arc segments on inner ring
                    Group {
                        Circle()
                            .trim(from: 0.05, to: 0.12)
                            .stroke(Color.hudCyan, lineWidth: 2)
                            .padding(46)
                        Circle()
                            .trim(from: 0.55, to: 0.62)
                            .stroke(Color.hudCyan, lineWidth: 2)
                            .padding(46)
                    }
                    .rotationEffect(.degrees(innerRotation))
                )

            // Center disc
            Circle()
                .fill(Color.void)
                .padding(58)

            // Center text
            VStack(spacing: 4) {
                Text("CHECKING")
                    .font(HUDFont.mono(10))
                    .foregroundStyle(Color.dim)
                    .kerning(1.5)
                Text(formatCurrency(checking))
                    .font(HUDFont.display(28, weight: .bold))
                    .foregroundStyle(isLow ? Color.hudRed : Color.hudCyan)
                    .monospacedDigit()
                    .shadow(color: isLow ? Color.hudRed.opacity(0.6) : Color.hudCyan.opacity(0.6), radius: 6)
                if card > 0 {
                    Text("\(formatCurrency(card)) owed on card")
                        .font(HUDFont.mono(11))
                        .foregroundStyle(Color.hudRed.opacity(0.8))
                        .monospacedDigit()
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { animateArcs = true }
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) { outerRotation = 360 }
            withAnimation(.linear(duration: 70).repeatForever(autoreverses: false)) { innerRotation = -360 }
        }
    }

    private func formatCurrency(_ val: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: val)) ?? "$\(val)"
    }
}

struct SampleBadge: View {
    var body: some View {
        Text("SAMPLE DATA")
            .font(HUDFont.mono(9, weight: .medium))
            .foregroundStyle(Color.hudGold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.goldDim.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.hudGold.opacity(0.5), lineWidth: 1))
    }
}
