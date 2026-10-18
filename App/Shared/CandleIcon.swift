import SwiftUI

/// Two Shabbat candles with small flames. Used for candle lighting everywhere instead of the plain flame symbol.
struct CandleIcon: View {
    @ScaledMetric(relativeTo: .body) private var scaled: CGFloat = 17
    var size: CGFloat?

    var body: some View {
        let side = size ?? scaled
        ZStack {
            candle(at: 0.30, side: side)
            candle(at: 0.70, side: side)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    private func candle(at x: CGFloat, side: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.05, style: .continuous)
                .frame(width: side * 0.2, height: side * 0.5)
                .position(x: side * x, y: side * 0.74)
            CandleFlame()
                .frame(width: side * 0.16, height: side * 0.27)
                .position(x: side * x, y: side * 0.29)
        }
        .frame(width: side, height: side)
    }
}

private struct CandleFlame: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.68),
                      control1: CGPoint(x: rect.midX + rect.width * 0.2, y: rect.height * 0.28),
                      control2: CGPoint(x: rect.maxX, y: rect.height * 0.42))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY * 0.68),
                      control1: CGPoint(x: rect.maxX, y: rect.maxY * 1.05),
                      control2: CGPoint(x: rect.minX, y: rect.maxY * 1.05))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                      control1: CGPoint(x: rect.minX, y: rect.height * 0.42),
                      control2: CGPoint(x: rect.midX - rect.width * 0.2, y: rect.height * 0.28))
        path.closeSubpath()
        return path
    }
}

/// The icon of a time kind: the candles for candle lighting, an SF Symbol for everything else.
struct KindIcon: View {
    let symbol: String
    var size: CGFloat?

    var body: some View {
        if symbol == "candles" {
            CandleIcon(size: size)
        } else {
            Image(systemName: symbol)
        }
    }
}
