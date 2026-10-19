import CryptoKit
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

/// A "several rings" alarm is a handful of Apple system alarms, one per ring, so every ring sounds like a real alarm:
/// through the silent switch and Focus, with the phone locked. Each ring is stopped with its Stop button.
enum ShabbatAlarmService {
    /// How many system alarms one app keeps for rings.
    static let budget = 40
    private static let registryKey = "shabbatWake.ringAlarmIDs.v1"

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

    /// The same ring always gets the same alarm ID, so it can be found again to be cancelled.
    static func ringUUID(_ ringID: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(ringID.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private static var registry: [String: [String]] {
        get { UserDefaults.standard.dictionary(forKey: registryKey) as? [String: [String]] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: registryKey) }
    }

    static func schedule(_ alarm: WakeAlarm) async throws {
        let rings = RingPlanner.rings(for: alarm)
        guard !rings.isEmpty else { throw ShabbatAlarmError.nothingToSchedule }
        guard rings.count <= budget else { throw ShabbatAlarmError.tooManyRings }
        await cancel(id: alarm.id)
        var scheduled: [UUID] = []
        do {
            for ring in rings {
                let id = ringUUID(ring.id)
                try await NativeAlarmKitService.scheduleRing(id: id, alarm: alarm, ring: ring)
                scheduled.append(id)
            }
        } catch {
            for id in scheduled { try? await NativeAlarmKitService.cancel(id: id) }
            throw error
        }
        var all = registry
        all[alarm.id.uuidString] = scheduled.map(\.uuidString)
        registry = all
    }

    static func cancel(id: UUID) async {
        var all = registry
        for text in all[id.uuidString] ?? [] {
            if let ring = UUID(uuidString: text) { try? await NativeAlarmKitService.cancel(id: ring) }
        }
        all[id.uuidString] = nil
        registry = all
        // Older builds rang as notifications; clear any that are still pending.
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(RingPlanner.idPrefix + id.uuidString) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
    }

    /// Older builds rang as notifications. Any that are still pending would fire at odd times next to the real alarms.
    static func clearLegacyNotificationRings() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(RingPlanner.idPrefix) }
        if !pending.isEmpty { center.removePendingNotificationRequests(withIdentifiers: pending) }
        let delivered = await center.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(RingPlanner.idPrefix) }
        if !delivered.isEmpty { center.removeDeliveredNotifications(withIdentifiers: delivered) }
    }

    /// Whether every ring this alarm needs is still known to the system. Used to decide if it must be scheduled again.
    static func isComplete(_ alarm: WakeAlarm, scheduled: Set<UUID>) -> Bool {
        let expected = RingPlanner.rings(for: alarm).map { ringUUID($0.id) }
        return !expected.isEmpty && expected.allSatisfy(scheduled.contains)
    }

    /// Alarms that have at least one ring scheduled.
    static func alarmIDs(scheduled: Set<UUID>) -> Set<UUID> {
        Set(registry.compactMap { key, rings -> UUID? in
            guard rings.contains(where: { UUID(uuidString: $0).map(scheduled.contains) ?? false }) else { return nil }
            return UUID(uuidString: key)
        })
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
        // An alarm the system no longer knows (already rang, restored backup) must still be deletable.
        try? await NativeAlarmKitService.cancel(id: alarm.id)
    }
}

/// Without this, a notification that arrives while the app is open makes no sound and shows nothing.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
