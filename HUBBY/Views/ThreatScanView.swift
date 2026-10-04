import SwiftUI

struct ThreatScanView: View {
    @Environment(DashboardStore.self) private var store
    @State private var showFlagged = true
    @State private var expandedID: String? = nil

    private var flagged: [MailAlert] {
        store.activeAlerts.filter { $0.severity >= .warning }
    }
    private var all: [MailAlert] { store.activeAlerts }
    private var displayed: [MailAlert] { showFlagged ? flagged : all }

    var body: some View {
        HUDFrame(index: "04", title: "Threat Scan",
                 timestamp: store.useSampleData ? "SAMPLE" : nil) {
            VStack(alignment: .leading, spacing: 10) {
                // Filter chips
                HStack(spacing: 8) {
                    FilterChip(label: "Flagged (\(flagged.count))", selected: showFlagged) {
                        showFlagged = true
                    }
                    FilterChip(label: "All 7 days (\(all.count))", selected: !showFlagged) {
                        showFlagged = false
                    }
                    Spacer()
                }

                if displayed.isEmpty {
                    Text("No items in this filter.")
                        .font(HUDFont.mono(12))
                        .foregroundStyle(Color.dim)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(displayed) { alert in
                        ThreatRow(alert: alert, isExpanded: expandedID == alert.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedID = expandedID == alert.id ? nil : alert.id
                                }
                            }
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(HUDFont.mono(11))
                .foregroundStyle(selected ? Color.hudCyan : Color.dim)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(selected ? Color.lineHot.opacity(0.4) : Color.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(selected ? Color.hudCyan.opacity(0.5) : Color.line, lineWidth: 1))
        }
    }
}

struct ThreatRow: View {
    let alert: MailAlert
    let isExpanded: Bool

    private var severityColor: Color {
        switch alert.severity {
        case .critical: return .hudRed
        case .warning: return .hudGold
        case .info: return .hudGreen
        }
    }

    private var severityLetter: String {
        switch alert.severity {
        case .critical: return "C"
        case .warning: return "W"
        case .info: return "I"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                // Severity square
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(severityColor.opacity(0.15))
                        .frame(width: 22, height: 22)
                    Text(severityLetter)
                        .font(HUDFont.mono(11, weight: .medium))
                        .foregroundStyle(severityColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(alert.subject)
                            .font(HUDFont.display(12))
                            .foregroundStyle(Color.hudText)
                            .lineLimit(1)
                        if alert.isNew {
                            Text("NEW")
                                .font(HUDFont.mono(8))
                                .foregroundStyle(Color.void)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(severityColor)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }
                    HStack(spacing: 6) {
                        Text(alert.classificationLabel)
                            .font(HUDFont.mono(10))
                            .foregroundStyle(severityColor)
                        Text("· \(alert.senderDomain)")
                            .font(HUDFont.mono(10))
                            .foregroundStyle(Color.dim)
                        Spacer()
                        Text(alert.relativeTime)
                            .font(HUDFont.mono(10))
                            .foregroundStyle(Color.faint)
                    }
                }
            }
            .padding(.vertical, 8)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider().background(Color.line)
                    Text(alert.snippet)
                        .font(HUDFont.mono(11))
                        .foregroundStyle(Color.dim)
                    if let url = alert.gmailLink {
                        Link("Open in Gmail →", destination: url)
                            .font(HUDFont.mono(11))
                            .foregroundStyle(Color.hudCyan)
                    }
                }
                .padding(.bottom, 8)
                .padding(.leading, 32)
            }
        }
        .padding(.horizontal, 2)
        .background(Color.panel2.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
