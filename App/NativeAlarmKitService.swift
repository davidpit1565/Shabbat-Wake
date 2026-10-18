import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

enum NativeAlarmKitService {
    static func schedule(_ alarm: WakeAlarm) async throws {
        guard #available(iOS 26.1, *) else { throw NativeAlarmKitError.unsupported }
        let manager = AlarmManager.shared
        if manager.authorizationState != .authorized {
            let state = try await manager.requestAuthorization()
            guard state == .authorized else { throw NativeAlarmKitError.permissionDenied }
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
        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: alarm.title)),
            countdown: nil,
            paused: nil
        )
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: ShabbatWakeAlarmMetadata(),
            tintColor: Color(red: 0.12, green: 0.42, blue: 0.92)
        )
        let sound: AlertConfiguration.AlertSound
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
        if #available(iOS 26.0, *) {
            try AlarmManager.shared.cancel(id: id)
        }
    }

    enum AuthorizationState { case authorized, denied, notDetermined, unsupported }

    static func authorizationState() -> AuthorizationState {
        guard #available(iOS 26.1, *) else { return .unsupported }
        switch AlarmManager.shared.authorizationState {
        case .authorized: return .authorized
        case .denied: return .denied
        default: return .notDetermined
        }
    }

    /// IDs of the alarms iOS currently has scheduled for this app, or nil where AlarmKit is unavailable.
    static func scheduledAlarmIDs() throws -> Set<UUID>? {
        guard #available(iOS 26.1, *) else { return nil }
        return Set(try AlarmManager.shared.alarms.map(\.id))
    }

    static func requestAuthorization() async throws -> Bool {
        guard #available(iOS 26.1, *) else { throw NativeAlarmKitError.unsupported }
        let manager = AlarmManager.shared
        if manager.authorizationState == .authorized { return true }
        return try await manager.requestAuthorization() == .authorized
    }
}

private struct ShabbatWakeAlarmMetadata: AlarmMetadata, Codable, Hashable {}

enum NativeAlarmKitError: LocalizedError {
    case unsupported
    case permissionDenied
    var errorDescription: String? {
        switch self {
        case .unsupported: return AppLanguage.text("System alarms require iOS 26.1 or later.")
        case .permissionDenied: return AppLanguage.text("Alarm permission was not granted.")
        }
    }
}
