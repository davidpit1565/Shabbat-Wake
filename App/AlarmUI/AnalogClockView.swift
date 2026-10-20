import SwiftUI

/// A plain analog clock face: twelve ticks, hour, minute and second hands. Used on Home when no alarm is set
/// and on the wake-up screen, where `pulse` (seconds) also draws glowing rings around it.
struct AnalogClockView: View {
    let date: Date
    var ink: Color = .white
    var accent: Color = Color(red: 1, green: 0.78, blue: 0.4)
    var pulse: Double? = nil

    var body: some View {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let seconds = Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1e9
        let minutes = Double(parts.minute ?? 0) + seconds / 60
        let hours = Double((parts.hour ?? 0) % 12) + minutes / 60
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let k = size / 260
            ZStack {
                if let pulse {
                    ForEach(0..<3, id: \.self) { index in
                        let phase = (pulse / 2.4 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                        Circle()
                            .stroke(ink.opacity(0.35 * (1 - phase)), lineWidth: 2)
                            .scaleEffect(0.7 + 0.6 * phase)
                    }
                }
                Circle().fill(ink.opacity(0.12))
                Circle().stroke(ink.opacity(0.7), lineWidth: 3 * k).padding(10 * k)
                ForEach(0..<12, id: \.self) { tick in
                    let major = tick % 3 == 0
                    Capsule()
                        .fill(ink.opacity(major ? 0.95 : 0.5))
                        .frame(width: (major ? 4 : 2) * k, height: (major ? 16 : 9) * k)
                        .offset(y: -102 * k)
                        .rotationEffect(.degrees(Double(tick) * 30))
                }
                hand(length: 62 * k, width: 6 * k, angle: hours / 12 * 360, color: ink)
                hand(length: 92 * k, width: 4 * k, angle: minutes / 60 * 360, color: ink)
                hand(length: 100 * k, width: 2 * k, angle: seconds / 60 * 360, color: accent)
                Circle().fill(ink).frame(width: 12 * k, height: 12 * k)
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func hand(length: CGFloat, width: CGFloat, angle: Double, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
    }
}
