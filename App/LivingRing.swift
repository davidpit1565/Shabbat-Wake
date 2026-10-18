import SwiftUI

/// The hero ring on the home screen: a calm, living instrument. Scanner ticks, two slow counter-rotating arcs
/// and a breathing core. It stands still when Reduce Motion is on.
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

        // The main ring is a full circle whose colour travels round it and whose glow pulses like something alive.
        let pulse = 0.5 + 0.5 * sin(t * 1.7)
        fullRing(&gc, center: center, radius: radius * (0.84 + 0.006 * sin(t * 1.7)), width: 4, angle: t * 0.5, pulse: pulse, from: secondary, to: primary)
        fullRing(&gc, center: center, radius: radius * 0.75, width: 2, angle: -t * 0.8 + 1, pulse: 1 - pulse, from: primary, to: secondary)
    }

    private func fullRing(_ gc: inout GraphicsContext, center: CGPoint, radius: CGFloat, width: CGFloat, angle: Double, pulse: Double, from: Color, to: Color) {
        let path = circle(center, radius)
        let shading = GraphicsContext.Shading.conicGradient(Gradient(colors: [from, to, from]), center: center, angle: .radians(angle))
        var glow = gc
        glow.opacity = 0.18 + 0.30 * pulse
        glow.addFilter(.blur(radius: 7))
        glow.stroke(path, with: shading, lineWidth: width * 3.5)
        var line = gc
        line.opacity = 0.78 + 0.22 * pulse
        line.stroke(path, with: shading, lineWidth: width)
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
    }
}
