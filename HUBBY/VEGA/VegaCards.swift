import SwiftUI

// MARK: - Card models

enum AssistantCard: Codable, Identifiable, Equatable {
    case balance(checking: Double, cardOwed: Double, source: String, age: String)
    case alertList(items: [String], level: String, source: String)
    case leadList(items: [LeadItem], source: String)
    case cashflow(income: Double, expenses: Double, net: Double, source: String)
    case explain(headline: String, body: String)
    case draft(to: String, subject: String, body: String)
    case reminderConfirm(title: String, fireAt: Date)
    case brief(text: String, source: String, age: String)

    var id: String {
        switch self {
        case .balance:          return "balance"
        case .alertList:        return "alertList"
        case .leadList:         return "leadList"
        case .cashflow:         return "cashflow"
        case .explain(let h, _): return "explain-\(h)"
        case .draft(_, let s, _): return "draft-\(s)"
        case .reminderConfirm(let t, _): return "reminder-\(t)"
        case .brief:            return "brief"
        }
    }

    struct LeadItem: Codable, Equatable {
        let title:   String
        let company: String?
        let score:   Int?
    }
}

// MARK: - Card view renderer

struct AssistantCardView: View {
    let card: AssistantCard

    var body: some View {
        switch card {
        case let .balance(checking, cardOwed, source, age):
            BalanceCard(checking: checking, cardOwed: cardOwed, source: source, age: age)
        case let .alertList(items, level, source):
            AlertListCard(items: items, level: level, source: source)
        case let .leadList(items, source):
            LeadListCard(items: items, source: source)
        case let .cashflow(income, expenses, net, source):
            CashflowCard(income: income, expenses: expenses, net: net, source: source)
        case let .explain(headline, bodyText):
            ExplainCard(headline: headline, bodyText: bodyText)
        case let .draft(to, subject, bodyText):
            DraftCard(to: to, subject: subject, bodyText: bodyText)
        case let .reminderConfirm(title, fireAt):
            ReminderCard(title: title, fireAt: fireAt)
        case let .brief(text, source, age):
            BriefCard(text: text, source: source, age: age)
        }
    }
}

// MARK: - Individual card views

private struct BalanceCard: View {
    let checking: Double; let cardOwed: Double; let source: String; let age: String
    var body: some View {
        HUDCardShell(icon: "banknote", label: "BALANCE", source: source, age: age) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHECKING").font(HUDFont.mono(9)).foregroundStyle(Color.faint)
                    Text(hudFmt(checking)).font(HUDFont.display(20)).foregroundStyle(Color.hudGold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("CARD OWED").font(HUDFont.mono(9)).foregroundStyle(Color.faint)
                    Text("-" + hudFmt(cardOwed)).font(HUDFont.display(20)).foregroundStyle(Color.hudRed)
                }
            }
        }
    }
}

private struct AlertListCard: View {
    let items: [String]; let level: String; let source: String
    var body: some View {
        HUDCardShell(icon: "exclamationmark.shield", label: "ALERTS [\(level)]", source: source, age: "") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(Color.hudRed)
                            .padding(.top, 5)
                        Text(item).font(HUDFont.mono(12)).foregroundStyle(Color.hudText)
                    }
                }
            }
        }
    }
}

private struct LeadListCard: View {
    let items: [AssistantCard.LeadItem]; let source: String
    var body: some View {
        HUDCardShell(icon: "briefcase", label: "LEADS", source: source, age: "") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.title) { lead in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(lead.title).font(HUDFont.mono(12, weight: .medium)).foregroundStyle(Color.hudText)
                        if let co = lead.company {
                            Text(co).font(HUDFont.mono(10)).foregroundStyle(Color.dim)
                        }
                    }
                }
            }
        }
    }
}

private struct CashflowCard: View {
    let income: Double; let expenses: Double; let net: Double; let source: String
    var body: some View {
        HUDCardShell(icon: "arrow.up.arrow.down", label: "CASH FLOW", source: source, age: "") {
            HStack(spacing: 16) {
                labelValue("IN",  value: income,   color: .hudGreen)
                labelValue("OUT", value: expenses, color: .hudRed)
                labelValue("NET", value: net,      color: net >= 0 ? .hudGreen : .hudRed)
            }
        }
    }

    private func labelValue(_ label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(HUDFont.mono(9)).foregroundStyle(Color.faint)
            Text(hudFmt(abs(value))).font(HUDFont.display(15)).foregroundStyle(color)
        }
    }
}

private struct ExplainCard: View {
    let headline: String; let bodyText: String
    var body: some View {
        HUDCardShell(icon: "info.circle", label: "EXPLAIN", source: "", age: "") {
            VStack(alignment: .leading, spacing: 6) {
                Text(headline).font(HUDFont.display(13, weight: .semibold)).foregroundStyle(Color.hudCyan)
                Text(bodyText).font(HUDFont.mono(12)).foregroundStyle(Color.hudText).lineSpacing(3)
            }
        }
    }
}

private struct DraftCard: View {
    let to: String; let subject: String; let bodyText: String
    var body: some View {
        HUDCardShell(icon: "envelope", label: "DRAFT", source: "read-only", age: "") {
            VStack(alignment: .leading, spacing: 4) {
                Text("To: \(to)").font(HUDFont.mono(11)).foregroundStyle(Color.dim)
                Text("Subject: \(subject)").font(HUDFont.mono(11, weight: .medium)).foregroundStyle(Color.hudText)
                Divider().background(Color.line)
                Text(bodyText).font(HUDFont.mono(11)).foregroundStyle(Color.hudText).lineSpacing(3)
                Text("Draft only — not sent.").font(HUDFont.mono(9)).foregroundStyle(Color.faint).padding(.top, 2)
            }
        }
    }
}

private struct ReminderCard: View {
    let title: String; let fireAt: Date
    var body: some View {
        HUDCardShell(icon: "bell.badge", label: "REMINDER SET", source: "", age: "") {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(HUDFont.mono(13, weight: .medium)).foregroundStyle(Color.hudText)
                Text(fireAt.formatted(date: .abbreviated, time: .shortened))
                    .font(HUDFont.mono(11)).foregroundStyle(Color.hudGold)
            }
        }
    }
}

private struct BriefCard: View {
    let text: String; let source: String; let age: String
    var body: some View {
        HUDCardShell(icon: "sun.horizon", label: "MORNING BRIEF", source: source, age: age) {
            Text(text).font(HUDFont.mono(12)).foregroundStyle(Color.hudText).lineSpacing(4)
        }
    }
}

// MARK: - Shell with icon + source chip

private struct HUDCardShell<Content: View>: View {
    let icon: String; let label: String; let source: String; let age: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(HUDFont.mono(10, weight: .medium))
                Spacer()
                if !source.isEmpty {
                    Text("\(source)\(age.isEmpty ? "" : " · \(age)")")
                        .font(HUDFont.mono(9))
                        .foregroundStyle(Color.faint)
                }
            }
            .foregroundStyle(Color.faint)

            content()
        }
        .padding(12)
        .background(Color.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.line, lineWidth: 1))
    }
}

// MARK: - Shared currency formatter

private func hudFmt(_ v: Double) -> String {
    "$" + String(format: v >= 1000 ? "%.0f" : "%.2f", v)
}
