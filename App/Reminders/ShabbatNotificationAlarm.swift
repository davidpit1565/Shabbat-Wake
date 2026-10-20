import Foundation
import UserNotifications

/// A "Shabbat alarm": a notification with no buttons whose sound ends by itself, so nobody has to touch the phone.
/// Unlike a system alarm it does not sound when the silent switch is on; it does break through Focus (time sensitive).
enum ShabbatNotificationAlarm {
    static let prefix = "shabbatwake.shabbat."
    /// Pending notifications are limited to 64 per app; reminders use a few of them.
    static let ringBudget = 20

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
        let rings = RingPlanner.rings(for: copy, limit: ringBudget)
        guard !rings.isEmpty else { throw ShabbatAlarmError.nothingToSchedule }
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

    /// The Shabbat alarms that still have a notification waiting.
    static func armedAlarmIDs() async -> Set<UUID> {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
        var ids: Set<UUID> = []
        for identifier in pending where identifier.hasPrefix(prefix) {
            let rest = identifier.dropFirst(prefix.count)
            if let text = rest.split(separator: ".").first, let id = UUID(uuidString: String(text)) { ids.insert(id) }
        }
        return ids
    }
}
