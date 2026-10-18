import AppIntents
import Foundation

/// What Siri answers. It reads the times and alarms the app keeps in the shared store, so it also works offline.
enum IntentAnswers {
    static var locale: Locale { TimeFormat.locale(language: AppLanguage.effectiveCode(for: AppLanguage.preference), format: UserDefaults.standard.string(forKey: TimeFormat.storageKey)) }

    static func nextTime(category: String, after now: Date = .now) -> Date? {
        SharedStore.load().times.first { $0.category == category && $0.date > now }?.date
    }

    static func nextAlarm(after now: Date = .now) -> Date? {
        SharedStore.load().alarms.compactMap { $0.nextFireDate(after: now) }.min()
    }

    /// "Friday 23 October" and "17:18", in the app's language.
    static func parts(_ date: Date) -> (day: String, time: String) {
        let day = date.formatted(Date.FormatStyle(locale: locale).weekday(.wide).day().month(.wide))
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
        return (day, time)
    }

    static func sentence(_ format: String, for date: Date) -> String {
        let (day, time) = parts(date)
        return String(format: AppLanguage.text(format), day, time)
    }

    static var needsSetup: String { AppLanguage.text("Open Shabbat Waker once and allow location to get times.") }
}

struct NextCandleLightingIntent: AppIntent {
    static var title: LocalizedStringResource = "Next candle lighting"
    static var description = IntentDescription("Tells you when the next candle lighting is.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let date = IntentAnswers.nextTime(category: "candles") else {
            return .result(dialog: IntentDialog(stringLiteral: IntentAnswers.needsSetup))
        }
        return .result(dialog: IntentDialog(stringLiteral: IntentAnswers.sentence("Candle lighting is on %@ at %@.", for: date)))
    }
}

struct ShabbatEndsIntent: AppIntent {
    static var title: LocalizedStringResource = "When Shabbat ends"
    static var description = IntentDescription("Tells you when Shabbat ends.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let date = IntentAnswers.nextTime(category: "havdalah") else {
            return .result(dialog: IntentDialog(stringLiteral: IntentAnswers.needsSetup))
        }
        return .result(dialog: IntentDialog(stringLiteral: IntentAnswers.sentence("Shabbat ends on %@ at %@.", for: date)))
    }
}

struct NextAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "My next alarm"
    static var description = IntentDescription("Tells you when your next alarm rings.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let date = IntentAnswers.nextAlarm() else {
            return .result(dialog: IntentDialog(stringLiteral: AppLanguage.text("No alarm is set.")))
        }
        return .result(dialog: IntentDialog(stringLiteral: IntentAnswers.sentence("Your next alarm is on %@ at %@.", for: date)))
    }
}

struct ShabbatShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextCandleLightingIntent(),
            phrases: ["Candle lighting in \(.applicationName)", "When is candle lighting in \(.applicationName)"],
            shortTitle: "Candle lighting",
            systemImageName: "flame"
        )
        AppShortcut(
            intent: ShabbatEndsIntent(),
            phrases: ["When does Shabbat end in \(.applicationName)", "Shabbat ends in \(.applicationName)"],
            shortTitle: "Shabbat ends",
            systemImageName: "moon.stars"
        )
        AppShortcut(
            intent: NextAlarmIntent(),
            phrases: ["Next alarm in \(.applicationName)", "My alarm in \(.applicationName)"],
            shortTitle: "Next alarm",
            systemImageName: "alarm"
        )
    }
}
