import SwiftUI

struct PaidLeadsView: View {
    @Environment(DashboardStore.self) private var store
    @State private var sortByHourly = false

    private var sorted: [JobLead] {
        let leads = store.leads
        if sortByHourly {
            return leads.sorted { $0.hourlyEquivalent > $1.hourlyEquivalent }
        } else {
            return leads.sorted { $0.totalPay > $1.totalPay }
        }
    }

    var body: some View {
        HUDFrame(index: "05", title: "Paid Leads",
                 timestamp: store.useSampleData ? "SAMPLE" : nil) {
            VStack(alignment: .leading, spacing: 12) {
                // Sort toggle
                HStack(spacing: 8) {
                    SortChip(label: "Payout", selected: !sortByHourly) { sortByHourly = false }
                    SortChip(label: "Per Hour", selected: sortByHourly) { sortByHourly = true }
                    Spacer()
                    Text("\(sorted.count) lead\(sorted.count == 1 ? "" : "s")")
                        .font(HUDFont.mono(10))
                        .foregroundStyle(Color.faint)
                }

                if sorted.isEmpty {
                    Text("No paid leads found in the last 3 days.")
                        .font(HUDFont.mono(12))
                        .foregroundStyle(Color.dim)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, lead in
                        LeadCard(lead: lead, isTop: idx == 0)
                    }
                }
            }
        }
    }
}

struct SortChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(HUDFont.mono(11))
                .foregroundStyle(selected ? Color.hudGold : Color.dim)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(selected ? Color.goldDim.opacity(0.3) : Color.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(selected ? Color.hudGold.opacity(0.5) : Color.line, lineWidth: 1))
        }
    }
}

struct LeadCard: View {
    let lead: JobLead
    let isTop: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title + source
            HStack {
                Text(lead.title)
                    .font(HUDFont.display(14, weight: isTop ? .bold : .semibold))
                    .foregroundStyle(isTop ? Color.hudGold : Color.hudText)
                    .lineLimit(2)
                Spacer()
                Text(lead.source.rawValue.uppercased())
                    .font(HUDFont.mono(9))
                    .foregroundStyle(Color.faint)
            }

            // Role
            if let role = lead.role {
                Text(role)
                    .font(HUDFont.mono(11))
                    .foregroundStyle(Color.dim)
                    .lineLimit(1)
            }

            // Pay
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(lead.payDisplay)
                    .font(HUDFont.display(20, weight: .bold))
                    .foregroundStyle(Color.hudGold)
                    .monospacedDigit()
                Text("≈ \(formatCurrency(lead.hourlyEquivalent))/hr")
                    .font(HUDFont.mono(12))
                    .foregroundStyle(Color.cyanDim)
                    .monospacedDigit()
            }

            // Meta row
            HStack(spacing: 8) {
                if let pt = lead.projectType {
                    MetaChip(text: pt, color: .faint)
                }
                if let loc = lead.location {
                    MetaChip(text: loc, color: .dim)
                }
                if let age = lead.ageRange {
                    MetaChip(text: age, color: .dim)
                }
                if let posted = lead.postedAgo {
                    MetaChip(text: posted, color: .faint)
                }
            }
            .lineLimit(1)

            if let url = lead.gmailLink {
                Link("View email →", destination: url)
                    .font(HUDFont.mono(10))
                    .foregroundStyle(Color.hudCyan)
            }
        }
        .padding(12)
        .background(Color.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isTop ? Color.hudGold.opacity(0.5) : Color.line, lineWidth: isTop ? 1.5 : 1)
        )
        .shadow(color: isTop ? Color.hudGold.opacity(0.1) : .clear, radius: 8)
    }

    private func formatCurrency(_ val: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: val)) ?? "$\(Int(val))"
    }
}

struct MetaChip: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(HUDFont.mono(9))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}
