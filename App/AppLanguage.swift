import SwiftUI
import UIKit

/// The language the app is showing: the user's choice, or the iPhone language when set to "system".
enum AppLanguage {
    static let storageKey = "preferredLanguage"

    static var preference: String {
        UserDefaults.standard.string(forKey: storageKey) ?? "system"
    }

    static func effectiveCode(for preference: String) -> String {
        if preference == "he" || preference == "en" { return preference }
        let system = Locale.preferredLanguages.first ?? "en"
        return system.hasPrefix("he") || system.hasPrefix("iw") ? "he" : "en"
    }

    static func isRightToLeft(_ code: String) -> Bool { code == "he" }

    /// Looks a string up in the chosen language, for text that is not shown through SwiftUI's own localization.
    static func text(_ key: String) -> String {
        let code = effectiveCode(for: preference)
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Makes UIKit-backed pieces (navigation bars, tab bar, sheets) follow the chosen direction too.
    static func applyDirection(for code: String) {
        UIView.appearance().semanticContentAttribute = isRightToLeft(code) ? .forceRightToLeft : .forceLeftToRight
    }
}

extension Date {
    /// Formats with the app's chosen language instead of the iPhone's.
    func formatted(in locale: Locale, date: Date.FormatStyle.DateStyle = .omitted, time: Date.FormatStyle.TimeStyle = .omitted) -> String {
        formatted(Date.FormatStyle(date: date, time: time, locale: locale))
    }

    /// The Hebrew calendar date, e.g. "7 Cheshvan 5787", or in Hebrew "ז׳ חשוון תשפ״ז" (letters, not digits).
    func hebrewDateString(in locale: Locale) -> String {
        if locale.identifier.hasPrefix("he") { return HebrewDateFormat.string(for: self, locale: locale) }
        return formatted(Date.FormatStyle(date: .long, time: .omitted, locale: locale, calendar: Calendar(identifier: .hebrew)))
    }
}

/// Hebrew dates the way they are written in Hebrew: the day and the year as letters.
enum HebrewDateFormat {
    static func string(for date: Date, locale: Locale) -> String {
        let calendar = Calendar(identifier: .hebrew)
        let parts = calendar.dateComponents([.day, .year], from: date)
        let month = DateFormatter()
        month.locale = locale
        month.calendar = calendar
        month.dateFormat = "MMMM"
        let day = numeral(parts.day ?? 1)
        let year = numeral((parts.year ?? 5000) % 1000)
        return "\(day) \(month.string(from: date)) \(year)"
    }

    /// 7 -> ז׳, 15 -> ט״ו, 16 -> ט״ז, 29 -> כ״ט, 787 -> תשפ״ז
    static func numeral(_ number: Int) -> String {
        var rest = number
        var letters: [Character] = []
        while rest >= 400 { letters.append("ת"); rest -= 400 }
        for (value, letter) in [(300, "ש"), (200, "ר"), (100, "ק")] where rest >= value {
            letters.append(Character(letter)); rest -= value
        }
        if rest == 15 { letters.append(contentsOf: ["ט", "ו"]); rest = 0 }
        else if rest == 16 { letters.append(contentsOf: ["ט", "ז"]); rest = 0 }
        for (value, letter) in [(90, "צ"), (80, "פ"), (70, "ע"), (60, "ס"), (50, "נ"), (40, "מ"), (30, "ל"), (20, "כ"), (10, "י")] where rest >= value {
            letters.append(Character(letter)); rest -= value
        }
        let units: [Character] = ["א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]
        if rest > 0 { letters.append(units[rest - 1]) }
        guard letters.count > 1 else { return String(letters) + "׳" }
        return String(letters.dropLast()) + "״" + String(letters.last!)
    }
}
