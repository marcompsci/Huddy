import SwiftUI

struct PriorityView: View {
    @Environment(DashboardStore.self) private var store

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    private var threatColor: Color {
        switch store.threatLevel {
        case .alert:   return .hudRed
        case .watch:   return .hudGold
        case .allClear: return .hudGreen
        }
    }

    // Use snapshot headline when available; fall back to computed description
    private var threatExplanation: String {
        if let h = store.headline { return h }
        switch store.threatLevel {
        case .alert:
            let isLow = (store.finance?.checkingBalance ?? 0) < store.lowBalanceThreshold
            if isLow { return "Balance below threshold" }
            let n = store.activeAlerts.filter { $0.severity == .critical && $0.isNew }.count
            return "\(n) critical item\(n == 1 ? "" : "s") flagged"
        case .watch:
            let n = store.activeAlerts.filter { $0.severity == .warning && $0.isNew }.count
            return "\(n) warning\(n == 1 ? "" : "s") in last 24 hours"
        case .allClear:
            return store.leads.isEmpty ? "Nothing new worth flagging." : "No new threats detected"
        }
    }

    private var priorityItems: [PriorityItem] {
        var items: [PriorityItem] = []
        if let lead = store.topLead { items.append(.lead(lead)) }
        for alert in store.activeAlerts.filter({ $0.isNew && $0.severity >= .warning }).prefix(4) {
            items.append(.alert(alert))
        }
        return items
    }

    var body: some View {
        HUDFrame(index: "02", title: "Priority", isAlert: store.threatLevel == .alert) {
            VStack(alignment: .leading, spacing: 14) {
                // Greeting
                (Text("\(greeting), ").font(HUDFont.display(16)).foregroundStyle(Color.hudText)
                 + Text("Omari.").font(HUDFont.display(16, weight: .bold)).foregroundStyle(Color.hudGold))

                // Threat readout
                HStack(spacing: 12) {
                    Text(store.threatLevel.rawValue)
                        .font(HUDFont.display(14, weight: .bold))
                        .foregroundStyle(threatColor)
                        .kerning(2)
                    Text(threatExplanation)
                        .font(HUDFont.mono(12))
                        .foregroundStyle(Color.dim)
                        .lineLimit(2)
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            Capsule()
                                .fill(i < barCount ? threatColor : Color.faint)
                                .frame(width: 4, height: 8 + CGFloat(i * 3))
                        }
                    }
                }
                .padding(.vertical, 8).padding(.horizontal, 10)
                .background(threatColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(threatColor.opacity(0.25), lineWidth: 1))

                if priorityItems.isEmpty {
                    Text("Nothing new worth flagging.")
                        .font(HUDFont.mono(13))
                        .foregroundStyle(Color.dim)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(priorityItems) { item in PriorityRow(item: item) }
                }
            }
        }
    }

    private var barCount: Int {
        switch store.threatLevel {
        case .alert:   return 5
        case .watch:   return 3
        case .allClear: return 1
        }
    }
}

// MARK: - Priority item types

enum PriorityItem: Identifiable {
    case alert(MailAlert)
    case lead(JobLead)
    var id: String {
        switch self {
        case .alert(let a): return "a-\(a.id)"
        case .lead(let l):  return "l-\(l.id)"
        }
    }
}

struct PriorityRow: View {
    let item: PriorityItem
    var body: some View {
        switch item {
        case .alert(let a): AlertPriorityRow(alert: a)
        case .lead(let l):  LeadPriorityRow(lead: l)
        }
    }
}

struct AlertPriorityRow: View {
    @Environment(DashboardStore.self) private var store
    let alert: MailAlert

    private var color: Color {
        switch alert.severity { case .critical: return .hudRed; case .warning: return .hudGold; case .info: return .hudGreen }
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(color).frame(width: 3)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.subject).font(HUDFont.display(13)).foregroundStyle(Color.hudText).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(alert.classificationLabel).font(HUDFont.mono(10)).foregroundStyle(color)
                        Text("· \(alert.senderDomain)").font(HUDFont.mono(10)).foregroundStyle(Color.dim)
                        Text(alert.relativeTime).font(HUDFont.mono(10)).foregroundStyle(Color.faint)
                    }
                }
                Spacer()
                HStack(spacing: 6) {
                    if let url = alert.gmailLink { Link("Open", destination: url).font(HUDFont.mono(10)).foregroundStyle(Color.hudCyan) }
                    Button("Clear") { store.dismissAlert(id: alert.id) }.font(HUDFont.mono(10)).foregroundStyle(Color.faint)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .background(Color.panel2).clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct LeadPriorityRow: View {
    let lead: JobLead
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.hudGold).frame(width: 3)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lead.title).font(HUDFont.display(13)).foregroundStyle(Color.hudText).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(lead.payDisplay).font(HUDFont.mono(11, weight: .medium)).foregroundStyle(Color.hudGold).monospacedDigit()
                        Text("≈ \(fmt(lead.hourlyEquivalent))/hr").font(HUDFont.mono(10)).foregroundStyle(Color.dim)
                        Text(lead.source.rawValue).font(HUDFont.mono(9)).foregroundStyle(Color.faint)
                    }
                }
                Spacer()
                if let url = lead.gmailLink { Link("Open", destination: url).font(HUDFont.mono(10)).foregroundStyle(Color.hudCyan) }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .background(Color.panel2).clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func fmt(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$\(Int(v))"
    }
}
