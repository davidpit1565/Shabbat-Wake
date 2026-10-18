import Foundation
import UserNotifications

struct PlannedRing: Equatable {
    let id: String
    let alarmID: UUID
    let ordinal: Int
    /// For a repeating ring, the next time it will fire.
    let fireDate: Date
    let components: DateComponents
    let repeats: Bool
}

/// Works out when each ring of a Shabbat alarm goes off. Pure, so it can be tested.
enum RingPlanner {
    static let idPrefix = "shabbatwake.ring."

    static func rings(for alarm: WakeAlarm, now: Date = .now, calendar: Calendar = .current, limit: Int = ShabbatAlarmService.budget) -> [PlannedRing] {
        guard alarm.isEnabled, let plan = alarm.ringPlan?.normalized() else { return [] }
        var base = DateComponents()
        base.hour = alarm.hour
        base.minute = alarm.minute
        base.second = 0
        var rings: [PlannedRing] = []

        func add(from occurrence: Date, key: String, repeats: Bool) {
            for ordinal in 0..<plan.count {
                guard let fire = calendar.date(byAdding: .minute, value: ordinal * plan.intervalMinutes, to: occurrence) else { continue }
                guard repeats || fire > now.addingTimeInterval(2) else { continue }
                var parts = calendar.dateComponents([.weekday, .hour, .minute], from: fire)
                if !repeats { parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire) }
                rings.append(PlannedRing(id: "\(idPrefix)\(alarm.id.uuidString).\(key).\(ordinal)", alarmID: alarm.id, ordinal: ordinal, fireDate: fire, components: parts, repeats: repeats))
            }
        }

        if alarm.repeatsWeekly && !alarm.weekdays.isEmpty {
            for weekday in alarm.weekdays.sorted() {
                var match = base
                match.weekday = weekday
                if let weeks = alarm.weeksLimit {
                    var cursor = alarm.armedAt ?? alarm.createdAt
                    for _ in 0..<weeks {
                        guard let occurrence = calendar.nextDate(after: cursor, matching: match, matchingPolicy: .nextTime) else { break }
                        add(from: occurrence, key: "d\(Int(occurrence.timeIntervalSince1970))", repeats: false)
                        cursor = occurrence
                    }
                } else if let occurrence = calendar.nextDate(after: now, matching: match, matchingPolicy: .nextTime) {
                    add(from: occurrence, key: "w\(weekday)", repeats: true)
                }
            }
        } else if let occurrence = calendar.nextDate(after: alarm.armedAt ?? alarm.createdAt, matching: base, matchingPolicy: .nextTime) {
            add(from: occurrence, key: "d\(Int(occurrence.timeIntervalSince1970))", repeats: false)
        }
        // Repeating rings always stay; one-off rings are limited to the soonest ones.
        let repeating = rings.filter(\.repeats)
        let dated = rings.filter { !$0.repeats }.sorted { $0.fireDate < $1.fireDate }
        return repeating + Array(dated.prefix(max(0, limit - repeating.count)))
    }
}

enum ShabbatAlarmError: LocalizedError {
    case notificationsDenied
    case tooManyRings
    case nothingToSchedule
    var errorDescription: String? {
        switch self {
        case .notificationsDenied: return AppLanguage.text("Notifications are turned off for this app, so a Shabbat alarm cannot ring.")
        case .tooManyRings: return AppLanguage.text("There are too many Shabbat alarm rings scheduled. Lower the number of rings or alarms.")
        case .nothingToSchedule: return AppLanguage.text("This alarm has no upcoming time to ring.")
        }
    }
}

/// Shabbat alarms ring as notifications with a short sound, so they stop by themselves even if the phone stays in a drawer.
/// iOS plays a notification sound for at most 30 seconds, and it follows the ringer switch.
enum ShabbatAlarmService {
    /// iOS keeps 64 pending notifications per app; reminders use up to 20, alarms up to 40.
    static let budget = 40

    static func soundFileName(for alarm: WakeAlarm) -> String {
        let plan = (alarm.ringPlan ?? .standard).normalized()
        let tone: String
        switch alarm.soundID {
        case "gentle": tone = "GentleChime"
        case "sunrise": tone = "SunriseSequence"
        default: tone = "ClassicWake"
        }
        return "\(tone)_\(plan.seconds)s.wav"
    }

    static func schedule(_ alarm: WakeAlarm) async throws {
        let center = UNUserNotificationCenter.current()
        switch await ReminderScheduler.authorizationStatus() {
        case .authorized, .provisional, .ephemeral: break
        case .notDetermined:
            guard await ReminderScheduler.requestAuthorization() else { throw ShabbatAlarmError.notificationsDenied }
        default:
            throw ShabbatAlarmError.notificationsDenied
        }
        let others = await pendingRequests().filter { !$0.identifier.contains(alarm.id.uuidString) }.count
        let rings = RingPlanner.rings(for: alarm)
        guard !rings.isEmpty else { throw ShabbatAlarmError.nothingToSchedule }
        guard others + rings.count <= budget else { throw ShabbatAlarmError.tooManyRings }
        await cancel(id: alarm.id)
        for ring in rings {
            let content = UNMutableNotificationContent()
            content.title = alarm.title
            content.body = AppLanguage.text("Shabbat alarm")
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundFileName(for: alarm)))
            content.threadIdentifier = alarm.id.uuidString
            content.interruptionLevel = .timeSensitive
            let trigger = UNCalendarNotificationTrigger(dateMatching: ring.components, repeats: ring.repeats)
            try await center.add(UNNotificationRequest(identifier: ring.id, content: content, trigger: trigger))
        }
    }

    /// Rings once, ten seconds from now, the same way a Shabbat alarm does. For checking sound and permissions by hand.
    static func scheduleTest() async throws {
        let center = UNUserNotificationCenter.current()
        switch await ReminderScheduler.authorizationStatus() {
        case .authorized, .provisional, .ephemeral: break
        case .notDetermined:
            guard await ReminderScheduler.requestAuthorization() else { throw ShabbatAlarmError.notificationsDenied }
        default:
            throw ShabbatAlarmError.notificationsDenied
        }
        let content = UNMutableNotificationContent()
        content.title = AppLanguage.text("Test alarm")
        content.body = AppLanguage.text("Shabbat alarm")
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "ClassicWake_10s.wav"))
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        try await center.add(UNNotificationRequest(identifier: "shabbatWake.test", content: content, trigger: trigger))
    }

    static func cancel(id: UUID) async {
        let center = UNUserNotificationCenter.current()
        let ids = await pendingRequests().map(\.identifier).filter { $0.hasPrefix(RingPlanner.idPrefix + id.uuidString) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func pendingAlarmIDs() async -> Set<UUID> {
        Set(await pendingRequests().compactMap { request -> UUID? in
            guard request.identifier.hasPrefix(RingPlanner.idPrefix) else { return nil }
            let rest = request.identifier.dropFirst(RingPlanner.idPrefix.count)
            return UUID(uuidString: String(rest.prefix(36)))
        })
    }

    private static func pendingRequests() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().filter { $0.identifier.hasPrefix(RingPlanner.idPrefix) }
    }
}

/// Chooses between a normal system alarm and a Shabbat alarm that stops by itself.
enum AlarmScheduler {
    static func schedule(_ alarm: WakeAlarm) async throws {
        if alarm.ringPlan != nil {
            try? await NativeAlarmKitService.cancel(id: alarm.id)
            try await ShabbatAlarmService.schedule(alarm)
        } else {
            await ShabbatAlarmService.cancel(id: alarm.id)
            try await NativeAlarmKitService.schedule(alarm)
        }
    }

    static func cancel(_ alarm: WakeAlarm) async throws {
        await ShabbatAlarmService.cancel(id: alarm.id)
        do {
            try await NativeAlarmKitService.cancel(id: alarm.id)
        } catch {
            if alarm.ringPlan == nil { throw error }
        }
    }
}

/// Without this, a notification that arrives while the app is open makes no sound and shows nothing.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
