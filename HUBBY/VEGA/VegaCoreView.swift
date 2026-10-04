import SwiftUI

// MARK: - Animated geometric face of VEGA

struct VegaCoreView: View {
    let state: VegaState
    var diameter: CGFloat = 200

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
            Canvas(opaque: false, colorMode: .linear) { ctx, size in
                draw(ctx: &ctx, size: size, t: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel(state.voiceOverLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Master drawing entry point

    private func draw(ctx: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let c  = CGPoint(x: size.width / 2, y: size.height / 2)
        let r  = min(size.width, size.height) / 2 * 0.96

        drawInnerDisc(&ctx, c: c, r: r, t: t)
        drawMiddleArcs(&ctx, c: c, r: r, t: t)
        if case .thinking = state, !reduceMotion {
            drawScanLine(&ctx, c: c, r: r, t: t)
        }
        drawOuterTicks(&ctx, c: c, r: r, t: t)
        if case .alert = state {
            drawAlertRim(&ctx, c: c, r: r, t: t)
        }
    }

    // MARK: - Layer 1: inner disc (radial gradient)

    private func drawInnerDisc(_ ctx: inout GraphicsContext, c: CGPoint, r: CGFloat, t: TimeInterval) {
        let discR = r * 0.40
        let color: Color
        let alpha: CGFloat

        switch state {
        case .idle:
            let breathe = CGFloat(0.5 + 0.5 * sin(t / 4.0 * .pi * 2))
            color = .hudCyan
            alpha = reduceMotion ? 0.42 : (0.26 + breathe * 0.18)

        case .listening(let l):
            color = .hudCyan
            alpha = reduceMotion ? 0.52 : (0.40 + l * 0.38)

        case .thinking:
            // 3 Hz shimmer
            let shimmer = CGFloat(0.5 + 0.5 * sin(t / 0.333 * .pi * 2))
            color = .hudCyan
            alpha = reduceMotion ? 0.44 : (0.30 + shimmer * 0.24)

        case .speaking(let a):
            color = .hudGold
            alpha = reduceMotion ? 0.52 : (0.40 + a * 0.38)

        case .alert:
            let pulse = CGFloat(0.5 + 0.5 * sin(t * .pi * 2 * 2.0)) // 2 Hz
            color = .hudRed
            alpha = reduceMotion ? 0.60 : (0.46 + pulse * 0.32)
        }

        let rect = CGRect(x: c.x - discR, y: c.y - discR, width: discR * 2, height: discR * 2)
        let path = Path(ellipseIn: rect)
        ctx.fill(path, with: .radialGradient(
            Gradient(stops: [
                .init(color: color.opacity(Double(alpha)), location: 0),
                .init(color: color.opacity(Double(alpha * 0.30)), location: 0.58),
                .init(color: .clear, location: 1)
            ]),
            center: c,
            startRadius: 0,
            endRadius: discR
        ))
    }

    // MARK: - Layer 2: twelve segmented arcs (middle ring)

    private func drawMiddleArcs(_ ctx: inout GraphicsContext, c: CGPoint, r: CGFloat, t: TimeInterval) {
        let baseR    = r * 0.675
        let arcCount = 12

        let arcColor: Color
        let lineW: CGFloat

        switch state {
        case .alert:    arcColor = .hudRed;  lineW = 3.0
        case .speaking: arcColor = .hudGold; lineW = 2.5
        default:        arcColor = .hudCyan; lineW = 2.5
        }

        for i in 0..<arcCount {
            let sectorRad = .pi * 2 / Double(arcCount)
            let gap       = sectorRad * 0.065
            let startA    = Double(i) * sectorRad + gap - .pi / 2
            let endA      = Double(i + 1) * sectorRad - gap - .pi / 2

            let arcR: CGFloat
            switch state {
            case .thinking where !reduceMotion:
                // Each arc at a different phase of a 1.2 s sinusoidal oscillation → chase effect
                let phase = Double(i) / Double(arcCount) * .pi * 2
                arcR = baseR + CGFloat(sin(t / 1.2 * .pi * 2 + phase)) * r * 0.055

            case .idle:
                let breathe = CGFloat(0.5 + 0.5 * sin(t / 4.0 * .pi * 2))
                arcR = baseR + (reduceMotion ? 0 : breathe * r * 0.022)

            case .listening(let l):
                arcR = baseR + (reduceMotion ? 0 : l * r * 0.100)

            case .speaking(let a):
                arcR = baseR + (reduceMotion ? 0 : a * r * 0.080)

            case .alert:
                let pulse = CGFloat(0.5 + 0.5 * sin(t * .pi * 2 * 2.0))
                arcR = baseR + (reduceMotion ? 0 : pulse * r * 0.065)

            default:
                arcR = baseR
            }

            let path = Path { p in
                p.addArc(center: c, radius: arcR,
                         startAngle: .radians(startA),
                         endAngle:   .radians(endA), clockwise: false)
            }
            ctx.stroke(path, with: .color(arcColor.opacity(0.84)),
                       style: StrokeStyle(lineWidth: lineW, lineCap: .round))
        }
    }

    // MARK: - Layer 3: gold scan line (thinking only)

    private func drawScanLine(_ ctx: inout GraphicsContext, c: CGPoint, r: CGFloat, t: TimeInterval) {
        // Sweeps full circle in 2 s
        let angle  = fmod(t / 2.0 * .pi * 2, .pi * 2) - .pi / 2
        let innerR = r * 0.52
        let outerR = r * 0.80

        let path = Path { p in
            p.move(to: CGPoint(x: c.x + innerR * cos(angle), y: c.y + innerR * sin(angle)))
            p.addLine(to: CGPoint(x: c.x + outerR * cos(angle), y: c.y + outerR * sin(angle)))
        }
        ctx.stroke(path, with: .color(.hudGold.opacity(0.62)),
                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        // Fading trail behind the line
        let trailLen: Double = .pi / 5
        let trailPath = Path { p in
            p.addArc(center: c, radius: r * 0.68,
                     startAngle: .radians(angle - trailLen),
                     endAngle:   .radians(angle), clockwise: false)
        }
        ctx.stroke(trailPath, with: .color(.hudGold.opacity(0.18)),
                   style: StrokeStyle(lineWidth: 2))
    }

    // MARK: - Layer 4: seventy-two outer tick marks

    private func drawOuterTicks(_ ctx: inout GraphicsContext, c: CGPoint, r: CGFloat, t: TimeInterval) {
        let tickColor: Color
        switch state {
        case .alert:    tickColor = .hudRed
        case .speaking: tickColor = .hudGold
        default:        tickColor = .hudCyan
        }

        // Rotation period (seconds for full revolution)
        let period: Double
        switch state {
        case .alert:    period = 0  // stationary
        case .thinking: period = 8
        default:        period = 40
        }

        let rotation: Double = (reduceMotion || period == 0)
            ? 0
            : fmod(t / period * .pi * 2, .pi * 2)

        let innerR = r * 0.84

        for i in 0..<72 {
            let isLong = i % 6 == 0
            let angle  = Double(i) / 72.0 * .pi * 2 + rotation - .pi / 2
            let outerR = isLong ? r * 0.96 : r * 0.91

            let path = Path { p in
                p.move(to:    CGPoint(x: c.x + innerR * cos(angle), y: c.y + innerR * sin(angle)))
                p.addLine(to: CGPoint(x: c.x + outerR * cos(angle), y: c.y + outerR * sin(angle)))
            }
            ctx.stroke(path, with: .color(tickColor.opacity(isLong ? 0.68 : 0.28)),
                       style: StrokeStyle(lineWidth: isLong ? 1.5 : 1))
        }
    }

    // MARK: - Layer 5: alert outer rim (2 Hz pulse)

    private func drawAlertRim(_ ctx: inout GraphicsContext, c: CGPoint, r: CGFloat, t: TimeInterval) {
        let pulse = CGFloat(0.5 + 0.5 * sin(t * .pi * 2 * 2.0))
        let rimR  = r * 0.975
        let rect  = CGRect(x: c.x - rimR, y: c.y - rimR, width: rimR * 2, height: rimR * 2)
        let path  = Path(ellipseIn: rect)
        ctx.stroke(path, with: .color(.hudRed.opacity(Double(0.35 + pulse * 0.52))),
                   style: StrokeStyle(lineWidth: 2))
    }
}

// MARK: - Preview

#Preview("VEGA Core — States") {
    ZStack {
        Color.void.ignoresSafeArea()
        VStack(spacing: 32) {
            HStack(spacing: 24) {
                VegaCoreView(state: .idle, diameter: 120)
                VegaCoreView(state: .listening(level: 0.6), diameter: 120)
                VegaCoreView(state: .thinking, diameter: 120)
            }
            HStack(spacing: 24) {
                VegaCoreView(state: .speaking(amplitude: 0.5), diameter: 120)
                VegaCoreView(state: .alert, diameter: 120)
            }
        }
    }
}
