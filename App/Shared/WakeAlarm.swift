import Foundation

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

    var timeLabel: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
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
            return weekdays.compactMap { weekday -> Date? in
                var components = base
                components.weekday = weekday
                return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
            }.min()
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
