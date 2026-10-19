import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

enum NativeAlarmKitService {
    private static let weekdayMap: [Int: Locale.Weekday] = [
        1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday,
        5: .thursday, 6: .friday, 7: .saturday
    ]

    static func schedule(_ alarm: WakeAlarm) async throws {
        guard #available(iOS 26.1, *) else { throw NativeAlarmKitError.unsupported }
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
        try await submit(id: alarm.id, title: alarm.title, soundID: alarm.soundID, seconds: alarm.soundSeconds, schedule: schedule)
    }

    /// One ring of a "several rings" alarm: its own system alarm, at a fixed date or repeating on one weekday.
    static func scheduleRing(id: UUID, alarm: WakeAlarm, ring: PlannedRing) async throws {
        guard #available(iOS 26.1, *) else { throw NativeAlarmKitError.unsupported }
        let schedule: Alarm.Schedule
        if ring.repeats, let weekday = ring.components.weekday, let day = weekdayMap[weekday] {
            schedule = .relative(.init(
                time: .init(hour: ring.components.hour ?? 0, minute: ring.components.minute ?? 0),
                repeats: .weekly([day])
            ))
        } else {
            schedule = .fixed(ring.fireDate)
        }
        try await submit(id: id, title: alarm.title, soundID: alarm.soundID, seconds: alarm.soundSeconds, schedule: schedule)
    }

    /// A one-off alarm about a minute from now, for checking by hand that the alarm really sounds.
    static func scheduleTest() async throws {
        guard #available(iOS 26.1, *) else { throw NativeAlarmKitError.unsupported }
        try await submit(id: UUID(), title: AppLanguage.text("Test alarm"), soundID: "classic", seconds: RingPlan.defaultLength, schedule: .fixed(Date().addingTimeInterval(65)))
    }

    @available(iOS 26.1, *)
    private static func submit(id: UUID, title: String, soundID: String, seconds: Int, schedule: Alarm.Schedule) async throws {
        let manager = AlarmManager.shared
        if manager.authorizationState != .authorized {
            let state = try await manager.requestAuthorization()
            guard state == .authorized else { throw NativeAlarmKitError.permissionDenied }
        }
        let stopID = id.uuidString
        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title),
                secondaryButton: AlarmButton(
                    text: LocalizedStringResource(stringLiteral: AppLanguage.text("Open")),
                    textColor: .white,
                    systemImageName: "sun.max.fill"
                ),
                secondaryButtonBehavior: .custom
            ),
            countdown: nil,
            paused: nil
        )
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: ShabbatWakeAlarmMetadata(title: title),
            tintColor: Color(red: 0.12, green: 0.42, blue: 0.92)
        )
        // The file is as long as the person chose, so the sound ends by itself. If a file is missing, the system alarm sound is used.
        let file: String
        switch soundID {
        case "gentle": file = "GentleChime_\(seconds)s.wav"
        case "sunrise": file = "SunriseSequence_\(seconds)s.wav"
        default: file = "ClassicWake_\(seconds)s.wav"
        }
        let sound: AlertConfiguration.AlertSound = Bundle.main.url(forResource: (file as NSString).deletingPathExtension, withExtension: "wav") != nil ? .named(file) : .default
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: schedule,
            attributes: attributes,
            secondaryIntent: OpenWakeScreenIntent(alarmID: stopID, alarmTitle: title),
            sound: sound
        )
        _ = try await manager.schedule(id: id, configuration: configuration)
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
