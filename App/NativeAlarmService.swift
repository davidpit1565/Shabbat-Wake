import Foundation
import SwiftUI

#if canImport(AlarmKit)
import AlarmKit

@available(iOS 26.0, *)
enum NativeAlarmService {
    static func schedule(_ alarm: WakeAlarm) async throws {
        let manager = AlarmManager.shared
        if manager.authorizationState != .authorized {
            let state = try await manager.requestAuthorization()
            guard state == .authorized else {
                throw AlarmSchedulingError.permissionDenied
            }
        }

        let weekdayMap: [Int: Locale.Weekday] = [
            1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday,
            5: .thursday, 6: .friday, 7: .saturday
        ]
        let recurrence: Alarm.Schedule.Relative.Recurrence
        if alarm.repeatsWeekly && !alarm.weekdays.isEmpty {
            recurrence = .weekly(alarm.weekdays.sorted().compactMap { weekdayMap[$0] })
        } else {
            recurrence = .never
        }
        let schedule = Alarm.Schedule.relative(.init(
            time: .init(hour: alarm.hour, minute: alarm.minute),
            repeats: recurrence
        ))
        let presentation = AlarmPresentation(alert: AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: alarm.title)))
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: nil,
            tintColor: Color(red: 0.12, green: 0.42, blue: 0.92)
        )
        let sound: AlertSound
        switch alarm.soundID {
        case "gentle": sound = .named("GentleChime.wav")
        case "sunrise": sound = .named("SunriseSequence.wav")
        default: sound = .named("ClassicWake.wav")
        }
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: schedule,
            attributes: attributes,
            sound: sound
        )
        _ = try await manager.schedule(id: alarm.id, configuration: configuration)
    }

    static func cancel(id: UUID) async throws {
        try await AlarmManager.shared.cancel(id: id)
    }

    static func requestAuthorization() async throws -> Bool {
        let manager = AlarmManager.shared
        if manager.authorizationState == .authorized { return true }
        return try await manager.requestAuthorization() == .authorized
    }
}

enum AlarmSchedulingError: LocalizedError {
    case permissionDenied
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return String(localized: "Alarm permission was not granted.")
        }
    }
}
#else
enum AlarmSchedulingError: LocalizedError {
    case unsupported
    var errorDescription: String? { String(localized: "System alarms require iOS 26 or later.") }
}
enum NativeAlarmService {
    static func schedule(_ alarm: WakeAlarm) async throws { throw AlarmSchedulingError.unsupported }
    static func cancel(id: UUID) async throws {}
    static func requestAuthorization() async throws -> Bool { throw AlarmSchedulingError.unsupported }
}
#endif
