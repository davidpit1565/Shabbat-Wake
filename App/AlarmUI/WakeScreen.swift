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
                    AnalogClockView(date: context.date, pulse: t)
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

    private func stop() {
        if #available(iOS 26.1, *), let id = request.alarmID {
            try? AlarmManager.shared.stop(id: id)
        }
        onDone()
    }
}
