import Foundation
import UserNotifications

/// A "Shabbat alarm": a notification with no buttons whose sound ends by itself, so nobody has to touch the phone.
/// Unlike a system alarm it does not sound when the silent switch is on; it does break through Focus (time sensitive).
enum ShabbatNotificationAlarm {
    static let prefix = "shabbatwake.shabbat."
    /// Pending notifications are limited to 64 per app; candle-lighting reminders use some of them.
    /// The budget counts notifications (a 40 or 50 second ring is two of them), not rings.
    static let requestBudget = 36

    private struct Piece {
        let file: String
        let offset: Int
    }

    private static func pieces(for alarm: WakeAlarm) -> [Piece] {
        let tone: String
        switch alarm.soundID {
        case "gentle": tone = "GentleChime"
        case "sunrise": tone = "SunriseSequence"
        default: tone = "ClassicWake"
        }
        func file(_ label: String) -> String { "\(tone)_\(label)s.wav" }
        switch alarm.soundSeconds {
        case 10: return [Piece(file: file("n10"), offset: 0)]
        case 15: return [Piece(file: file("n15"), offset: 0)]
        case 20: return [Piece(file: file("n20"), offset: 0)]
        case 30: return [Piece(file: file("n29"), offset: 0)]
        case 40: return [Piece(file: file("n29"), offset: 0), Piece(file: file("n10"), offset: 30)]
        default: return [Piece(file: file("n29"), offset: 0), Piece(file: file("n20"), offset: 30)]
        }
    }

    static func requestsPerRing(_ alarm: WakeAlarm) -> Int { pieces(for: alarm).count }

    /// How many rings fit in the budget.
    static func ringLimit(for alarm: WakeAlarm) -> Int { max(1, requestBudget / requestsPerRing(alarm)) }

    /// The notifications this alarm should have waiting right now.
    static func expectedRequests(for alarm: WakeAlarm) -> Int {
        RingPlanner.rings(for: planned(alarm), limit: ringLimit(for: alarm)).count * requestsPerRing(alarm)
    }

    /// A single ring when the alarm has no ring plan.
    private static func planned(_ alarm: WakeAlarm) -> WakeAlarm {
        var copy = alarm
        if copy.ringPlan == nil { copy.ringPlan = RingPlan(count: 1, intervalMinutes: 5, seconds: RingPlan.defaultLength) }
        copy.isEnabled = true
        return copy
    }

    static func schedule(_ alarm: WakeAlarm) async throws {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional else { throw ShabbatAlarmError.notificationsDenied }

        let copy = planned(alarm)
        let rings = RingPlanner.rings(for: copy, limit: ringLimit(for: alarm))
        guard !rings.isEmpty else { throw ShabbatAlarmError.nothingToSchedule }
        // Repeating rings are never dropped, so too many of them cannot be scheduled at all.
        if rings.filter(\.repeats).count * requestsPerRing(alarm) > requestBudget { throw ShabbatAlarmError.tooManyRings }
        await cancel(id: alarm.id)
        let pieces = pieces(for: alarm)
        var added: [String] = []
        do {
            for ring in rings {
                let base = prefix + String(ring.id.dropFirst(RingPlanner.idPrefix.count))
                for (index, piece) in pieces.enumerated() {
                    let content = UNMutableNotificationContent()
                    content.title = alarm.title
                    content.body = AppLanguage.text("Shabbat alarm")
                    content.sound = UNNotificationSound(named: UNNotificationSoundName(piece.file))
                    content.interruptionLevel = .timeSensitive
                    var parts = ring.components
                    parts.second = piece.offset
                    // A dated ring is a fixed moment, even if the phone changes time zone.
                    if !ring.repeats { parts.timeZone = Calendar.current.timeZone }
                    let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: ring.repeats)
                    let identifier = "\(base).p\(index)"
                    try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
                    added.append(identifier)
                }
            }
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: added)
            throw error
        }
    }

    static func cancel(id: UUID) async {
        let center = UNUserNotificationCenter.current()
        let key = prefix + id.uuidString
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(key) }
        if !pending.isEmpty { center.removePendingNotificationRequests(withIdentifiers: pending) }
        let delivered = await center.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(key) }
        if !delivered.isEmpty { center.removeDeliveredNotifications(withIdentifiers: delivered) }
    }

    /// How many notifications each Shabbat alarm has waiting.
    static func armedCounts() async -> [UUID: Int] {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
        var counts: [UUID: Int] = [:]
        for identifier in pending where identifier.hasPrefix(prefix) {
            let rest = identifier.dropFirst(prefix.count)
            if let text = rest.split(separator: ".").first, let id = UUID(uuidString: String(text)) { counts[id, default: 0] += 1 }
        }
        return counts
    }
}
