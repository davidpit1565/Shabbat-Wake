import Foundation
import UserNotifications

/// "Remind me N minutes before candle lighting."
struct ShabbatReminder: Identifiable, Codable, Equatable {
    var id = UUID()
    var minutesBefore: Int
}

struct PlannedReminder: Equatable {
    let id: String
    let fireDate: Date
    let candleLighting: Date
    let minutesBefore: Int
}

enum ReminderPlanner {
    /// iOS keeps at most 64 pending notifications per app; reminders use up to 20 and Shabbat alarms up to 40.
    static let pendingLimit = 20

    /// The notifications to schedule: for each reminder and each upcoming candle lighting, soonest first.
    static func plan(reminders: [ShabbatReminder], candleTimes: [Date], now: Date = .now, limit: Int = pendingLimit) -> [PlannedReminder] {
        var planned: [PlannedReminder] = []
        for reminder in reminders {
            for candle in candleTimes {
                let fire = candle.addingTimeInterval(-Double(reminder.minutesBefore) * 60)
                guard fire > now.addingTimeInterval(5) else { continue }
                planned.append(PlannedReminder(
                    id: "\(ReminderScheduler.prefix)\(reminder.id.uuidString).\(Int(candle.timeIntervalSince1970))",
                    fireDate: fire,
                    candleLighting: candle,
                    minutesBefore: reminder.minutesBefore
                ))
            }
        }
        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }
}

enum ReminderScheduler {
    static let prefix = "shabbatwake.reminder."

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces every pending reminder notification with the current plan.
    static func reschedule(reminders: [ShabbatReminder], times: [ShabbatTimeItem], placeName: String?) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
        guard !reminders.isEmpty else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let candleTimes = times.filter { $0.category == "candles" }.map(\.date)
        let locale = TimeFormat.locale(language: AppLanguage.effectiveCode(for: AppLanguage.preference), format: UserDefaults.standard.string(forKey: TimeFormat.storageKey))
        let calendar = Calendar.current
        for item in ReminderPlanner.plan(reminders: reminders, candleTimes: candleTimes) {
            let content = UNMutableNotificationContent()
            content.title = String(format: AppLanguage.text("Candle lighting in %d minutes"), item.minutesBefore)
            let time = item.candleLighting.formatted(in: locale, time: .shortened)
            content.body = [String(format: AppLanguage.text("Candle lighting at %@"), time), placeName]
                .compactMap { $0 }.joined(separator: " · ")
            content.sound = .default
            var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            parts.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }
}

/// Saved reminders. Off until the person turns one on.
@MainActor
final class ReminderStore: ObservableObject {
    @Published private(set) var reminders: [ShabbatReminder] = []
    @Published private(set) var notificationsDenied = false
    private let key = "shabbatWake.reminders.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([ShabbatReminder].self, from: data) {
            reminders = saved
        }
    }

    func add(minutesBefore: Int) async {
        guard await ensureNotifications() else { return }
        reminders.append(ShabbatReminder(minutesBefore: minutesBefore))
        await commit()
    }

    func update(id: UUID, minutesBefore: Int) async {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[index].minutesBefore = minutesBefore
        await commit()
    }

    func delete(id: UUID) async {
        reminders.removeAll { $0.id == id }
        await commit()
    }

    /// Re-plans the notifications from the latest saved times. Call at launch and after times change.
    func reschedule() async {
        notificationsDenied = reminders.isEmpty ? false : await ReminderScheduler.authorizationStatus() == .denied
        let snapshot = SharedStore.load()
        await ReminderScheduler.reschedule(reminders: reminders, times: snapshot.times, placeName: snapshot.placeName)
    }

    private func ensureNotifications() async -> Bool {
        switch await ReminderScheduler.authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            notificationsDenied = false
            return true
        case .notDetermined:
            let granted = await ReminderScheduler.requestAuthorization()
            notificationsDenied = !granted
            return granted
        default:
            notificationsDenied = true
            return false
        }
    }

    private func commit() async {
        if let data = try? JSONEncoder().encode(reminders) { UserDefaults.standard.set(data, forKey: key) }
        await reschedule()
    }
}

/// Keeps the saved Shabbat times current without the person opening the Times tab.
enum TimesRefresher {
    private static let fetchedKey = "shabbatWake.timesFetchedAt"

    static func refreshIfNeeded() async {
        let snapshot = SharedStore.load()
        guard let latitude = snapshot.latitude, let longitude = snapshot.longitude, let zone = snapshot.timeZoneIdentifier else { return }
        let upcoming = snapshot.times.filter { $0.date > .now }.count
        let last = UserDefaults.standard.object(forKey: fetchedKey) as? Date ?? .distantPast
        guard upcoming < 6 || Date.now.timeIntervalSince(last) > 2 * 24 * 3600 else { return }
        guard let weeks = try? await ShabbatTimesService.fetchWeeks(
            latitude: latitude, longitude: longitude, timeZoneIdentifier: zone,
            from: Date.now.addingTimeInterval(-24 * 3600), weeks: 27
        ), !weeks.isEmpty else { return }
        UserDefaults.standard.set(Date.now, forKey: fetchedKey)
        WidgetSync.updateLocation(latitude: latitude, longitude: longitude, timeZoneIdentifier: zone, placeName: snapshot.placeName, times: weeks.timeItems)
    }
}
