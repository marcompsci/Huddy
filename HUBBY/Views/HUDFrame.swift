import SwiftUI

struct HUDFrame<Content: View>: View {
    let index: String
    let title: String
    var timestamp: String? = nil
    var isAlert: Bool = false
    @ViewBuilder let content: () -> Content

    var accentColor: Color { isAlert ? .hudRed : .hudCyan }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text(index)
                    .font(HUDFont.mono(11))
                    .foregroundStyle(Color.faint)
                Text(title.uppercased())
                    .font(HUDFont.display(12, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .kerning(2)
                Spacer()
                if let ts = timestamp {
                    Text(ts)
                        .font(HUDFont.mono(10))
                        .foregroundStyle(Color.dim)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.panel2)

            Divider().background(Color.line)

            content()
                .padding(14)
        }
        .background(
            LinearGradient(
                colors: [Color.panel2.opacity(0.92), Color.panel.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(ClippedCornerShape(cutSize: 14))
        .overlay(
            ClippedCornerShape(cutSize: 14)
                .stroke(Color.line, lineWidth: 1)
        )
        .overlay(
            LBracket(color: accentColor)
        )
    }
}

// MARK: - Clipped corner shape (top-right and bottom-left cut at 45°)

struct ClippedCornerShape: Shape {
    let cutSize: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { p in
            // Start top-left, go clockwise
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            // Top edge → cut top-right corner
            p.addLine(to: CGPoint(x: rect.maxX - cutSize, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cutSize))
            // Right edge → bottom-right (normal)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            // Bottom edge → cut bottom-left corner
            p.addLine(to: CGPoint(x: rect.minX + cutSize, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cutSize))
            p.closeSubpath()
        }
    }
}

// MARK: - L-shaped bracket overlay

struct LBracket: View {
    let color: Color
    let thickness: CGFloat = 2
    let length: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Top-left bracket
                Path { p in
                    p.move(to: CGPoint(x: 0, y: length))
                    p.addLine(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: length, y: 0))
                }
                .stroke(color, lineWidth: thickness)

                // Bottom-right bracket
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width - length, y: geo.size.height))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - length))
                }
                .stroke(color, lineWidth: thickness)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HUDFrame(index: "01", title: "Funds Core", timestamp: "Read 4m ago") {
        Text("Content goes here").foregroundStyle(Color.hudText)
    }
    .padding()
    .background(Color.void)
}
