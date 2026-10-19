import Foundation

/// How a Shabbat alarm rings: a few short rings that stop by themselves, so nobody has to touch the phone.
struct RingPlan: Codable, Equatable {
    var count: Int
    var intervalMinutes: Int
    var seconds: Int

    static let countChoices = Array(1...10)
    static let intervalChoices = [1, 2, 3, 5, 10, 15]
    static let secondChoices = [10, 15, 20, 30]
    /// How long each ring sounds, chosen per alarm.
    static let lengthChoices = [10, 15, 20, 30, 40, 50]
    static let defaultLength = 15
    static let standard = RingPlan(count: 3, intervalMinutes: 5, seconds: 15)

    /// Keeps every value inside what the app offers, so saved or imported data cannot produce an odd schedule.
    func normalized() -> RingPlan {
        RingPlan(
            count: min(max(count, 1), 10),
            intervalMinutes: RingPlan.intervalChoices.contains(intervalMinutes) ? intervalMinutes : 5,
            seconds: RingPlan.secondChoices.contains(seconds) ? seconds : 15
        )
    }
}

struct WakeAlarm: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var hour: Int
    var minute: Int
    var repeatsWeekly: Bool
    var weekdays: Set<Int>
    var isEnabled: Bool = true
    var soundID: String = "classic"
    var createdAt: Date = .now
    /// When the system alarm was last scheduled. One-time alarms count from here.
    var armedAt: Date?
    /// Set for a "Shabbat alarm": rings a few times and stops by itself. Nil means a normal system alarm.
    var ringPlan: RingPlan?
    /// For weekly alarms: stop repeating after this many weeks. Nil repeats until switched off.
    var weeksLimit: Int?
    /// How many seconds each ring sounds. Nil means the default.
    var ringSeconds: Int?

    var soundSeconds: Int { RingPlan.lengthChoices.contains(ringSeconds ?? 0) ? ringSeconds! : RingPlan.defaultLength }

    var timeLabel: String { timeLabel(in: .current) }

    func timeLabel(in locale: Locale) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
    }

    /// The next moment this alarm will ring, or nil if it is disabled or a one-time alarm that already rang.
    /// Weekday numbers follow `Calendar` (1 = Sunday ... 7 = Saturday).
    func nextFireDate(after now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard isEnabled else { return nil }
        var base = DateComponents()
        base.hour = hour
        base.minute = minute
        base.second = 0
        if repeatsWeekly && !weekdays.isEmpty {
            let next = weekdays.compactMap { weekday -> Date? in
                var components = base
                components.weekday = weekday
                return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
            }.min()
            guard let fire = next else { return nil }
            if let weeks = weeksLimit, fire >= (armedAt ?? createdAt).addingTimeInterval(Double(weeks) * 7 * 86400) { return nil }
            return fire
        }
        let armed = armedAt ?? createdAt
        guard let fire = calendar.nextDate(after: armed, matching: base, matchingPolicy: .nextTime), fire > now else {
            return nil
        }
        return fire
    }

    /// Short summary of when the alarm repeats, e.g. "Sat" or "Sun, Mon, Tue".
    func repeatSummary(locale: Locale) -> String {
        guard repeatsWeekly, !weekdays.isEmpty else { return "" }
        var calendar = Calendar.current
        calendar.locale = locale
        let symbols = calendar.shortWeekdaySymbols
        let names = weekdays.sorted().compactMap { day -> String? in
            symbols.indices.contains(day - 1) ? symbols[day - 1] : nil
        }
        return names.joined(separator: ", ")
    }
}
