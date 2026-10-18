import SwiftUI

/// The hero ring on the home screen: a calm, living instrument. Scanner ticks, slow counter-rotating arcs,
/// a few orbiting points and a breathing core. It stands still when Reduce Motion is on.
struct LivingRing: View {
    var primary: Color
    var secondary: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = reduceMotion ? 1.5 : context.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                draw(&gc, size: size, t: t)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(_ gc: inout GraphicsContext, size: CGSize, t: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2

        // Breathing core.
        let breath = 0.5 + 0.5 * sin(t * 1.1)
        let coreRadius = radius * (0.70 + 0.05 * breath)
        gc.fill(
            Path(ellipseIn: CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)),
            with: .radialGradient(
                Gradient(colors: [primary.opacity(0.20 + 0.10 * breath), secondary.opacity(0.06), .clear]),
                center: center, startRadius: 0, endRadius: coreRadius
            )
        )

        // Outer hairline.
        gc.stroke(circle(center, radius * 0.99), with: .color(secondary.opacity(0.25)), lineWidth: 1)

        // Scanner ticks: a bright spot sweeps round the rim.
        let tickCount = 72
        let scan = (t * 0.55).truncatingRemainder(dividingBy: 2 * .pi)
        for i in 0..<tickCount {
            let angle = Double(i) / Double(tickCount) * 2 * .pi
            var d = abs(angle - scan)
            d = min(d, 2 * .pi - d)
            let glow = exp(-d * 3.2)
            let inner = radius * (0.935 - 0.02 * glow)
            let outer = radius * 0.975
            var tick = Path()
            tick.move(to: point(center, inner, angle))
            tick.addLine(to: point(center, outer, angle))
            gc.stroke(tick, with: .color(primary.opacity(0.14 + 0.86 * glow)), style: StrokeStyle(lineWidth: i % 6 == 0 ? 2 : 1.2, lineCap: .round))
        }

        // Two arcs turning against each other.
        arc(&gc, center: center, radius: radius * 0.84, start: t * 0.45, length: 1.9, width: 3.2, from: secondary, to: primary)
        arc(&gc, center: center, radius: radius * 0.74, start: -t * 0.70 + 1.0, length: 1.2, width: 2.2, from: primary, to: secondary)

        // Fine dashed ring, drifting slowly.
        gc.stroke(
            circle(center, radius * 0.64),
            with: .color(secondary.opacity(0.35)),
            style: StrokeStyle(lineWidth: 1, dash: [1.5, 7], dashPhase: CGFloat(t * 6))
        )

        // Orbiting points with a soft halo.
        for k in 0..<3 {
            let angle = t * 0.9 + Double(k) * 2 * .pi / 3
            let p = point(center, radius * 0.64, angle)
            let halo = 7.0 + 2.0 * sin(t * 2 + Double(k))
            gc.fill(Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo, width: halo * 2, height: halo * 2)), with: .color(primary.opacity(0.18)))
            gc.fill(Path(ellipseIn: CGRect(x: p.x - 2.2, y: p.y - 2.2, width: 4.4, height: 4.4)), with: .color(.white.opacity(0.9)))
        }
    }

    private func arc(_ gc: inout GraphicsContext, center: CGPoint, radius: CGFloat, start: Double, length: Double, width: CGFloat, from: Color, to: Color) {
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(start + length), clockwise: false)
        gc.stroke(
            path,
            with: .linearGradient(Gradient(colors: [from.opacity(0.05), to]), startPoint: point(center, radius, start), endPoint: point(center, radius, start + length)),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
    }
}
