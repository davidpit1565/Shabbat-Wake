import AlarmKit
import SwiftUI

struct WakeRequest: Identifiable {
    let id = UUID()
    let alarmID: UUID?
    let title: String
}

/// Full-screen picture shown when the person opens a ringing alarm: a clock that moves, glowing rings and the time.
struct WakeScreen: View {
    let request: WakeRequest
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 30)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.03, green: 0.07, blue: 0.22), Color(red: 0.10, green: 0.30, blue: 0.75), Color(red: 0.98, green: 0.62, blue: 0.30)],
                    startPoint: UnitPoint(x: 0.5 + 0.1 * sin(t / 3), y: 0),
                    endPoint: UnitPoint(x: 0.5, y: 1)
                )
                .ignoresSafeArea()
                VStack(spacing: 28) {
                    Spacer()
                    clock(date: context.date, t: t)
                        .frame(width: 260, height: 260)
                    Text(context.date.formatted(in: locale, time: .shortened))
                        .font(.system(size: 54, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if !request.title.isEmpty {
                        Text(request.title)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                    Button {
                        stop()
                    } label: {
                        Text("Stop")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(Color(red: 0.03, green: 0.07, blue: 0.22))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func clock(date: Date, t: Double) -> some View {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let seconds = Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1e9
        let minutes = Double(parts.minute ?? 0) + seconds / 60
        let hours = Double((parts.hour ?? 0) % 12) + minutes / 60
        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                let phase = (t / 2.4 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                Circle()
                    .stroke(.white.opacity(0.35 * (1 - phase)), lineWidth: 2)
                    .scaleEffect(0.7 + 0.6 * phase)
            }
            Circle().fill(.white.opacity(0.12))
            Circle().stroke(.white.opacity(0.7), lineWidth: 3).padding(10)
            ForEach(0..<12, id: \.self) { tick in
                Capsule()
                    .fill(.white.opacity(tick % 3 == 0 ? 0.95 : 0.5))
                    .frame(width: tick % 3 == 0 ? 4 : 2, height: tick % 3 == 0 ? 16 : 9)
                    .offset(y: -102)
                    .rotationEffect(.degrees(Double(tick) * 30))
            }
            hand(length: 62, width: 6, angle: hours / 12 * 360, opacity: 1)
            hand(length: 92, width: 4, angle: minutes / 60 * 360, opacity: 1)
            hand(length: 100, width: 2, angle: seconds / 60 * 360, opacity: 0.85, tint: Color(red: 1, green: 0.78, blue: 0.4))
            Circle().fill(.white).frame(width: 12, height: 12)
        }
        .accessibilityHidden(true)
    }

    private func hand(length: CGFloat, width: CGFloat, angle: Double, opacity: Double, tint: Color = .white) -> some View {
        Capsule()
            .fill(tint.opacity(opacity))
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
    }

    private func stop() {
        if #available(iOS 26.1, *), let id = request.alarmID {
            try? AlarmManager.shared.stop(id: id)
        }
        onDone()
    }
}
