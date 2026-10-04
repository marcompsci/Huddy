import SwiftUI

struct CashFlowView: View {
    @Environment(DashboardStore.self) private var store

    private var f: FinanceOverview? { store.finance }

    var body: some View {
        HUDFrame(index: "03", title: "Cash Flow") {
            VStack(spacing: 14) {
                if store.useSampleData { SampleBadge() }

                // 2×3 readout grid
                let items: [(String, Double, Color)] = [
                    ("Card Owed",         f?.cardBalance ?? 0,                        .hudGold),
                    ("Net Accounts",      (f?.netWorth?.amount ?? 0),                 .hudText),
                    ("In This Month",     f?.currentMonth?.income?.amount ?? 0,       .hudGreen),
                    ("Out This Month",    f?.currentMonth?.spending?.amount ?? 0,     .hudText),
                    ("Net This Month",    f?.currentMonth?.net?.amount ?? 0,          netColor(f?.currentMonth?.net?.amount)),
                    ("Net Last Month",    f?.lastMonth?.net?.amount ?? 0,             netColor(f?.lastMonth?.net?.amount)),
                ]

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(items, id: \.0) { label, value, color in
                        ReadoutCell(label: label, value: value, color: color)
                    }
                }

                Divider().background(Color.line)

                // Category bar list
                Text("WHERE IT WENT")
                    .font(HUDFont.mono(9))
                    .foregroundStyle(Color.faint)
                    .kerning(1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let cats = f?.topCategories ?? []
                let max = cats.map { $0.amount?.amount ?? 0 }.max() ?? 1
                ForEach(cats) { cat in
                    CategoryBar(category: cat.category ?? "—",
                                amount: cat.amount?.amount ?? 0,
                                maxAmount: max)
                }
            }
        }
    }

    private func netColor(_ val: Double?) -> Color {
        guard let v = val else { return .hudText }
        return v >= 0 ? .hudGreen : .hudRed
    }
}

struct ReadoutCell: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(HUDFont.mono(9))
                .foregroundStyle(Color.faint)
                .kerning(1)
            Text(formatCurrency(value))
                .font(HUDFont.display(16, weight: .semibold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func formatCurrency(_ val: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: val)) ?? "$\(Int(val))"
    }
}

struct CategoryBar: View {
    let category: String
    let amount: Double
    let maxAmount: Double
    @State private var animate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(category)
                    .font(HUDFont.mono(11))
                    .foregroundStyle(Color.hudText)
                    .lineLimit(1)
                Spacer()
                Text(formatCurrency(amount))
                    .font(HUDFont.mono(11, weight: .medium))
                    .foregroundStyle(Color.hudCyan)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.line).frame(height: 4)
                    LinearGradient(colors: [Color.cyanDim, Color.hudCyan], startPoint: .leading, endPoint: .trailing)
                        .frame(width: animate ? geo.size.width * CGFloat(amount / max(maxAmount, 1)) : 0, height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .frame(height: 4)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { animate = true }
        }
    }

    private func formatCurrency(_ val: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: val)) ?? "$\(Int(val))"
    }
}
