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

    /// The Hebrew calendar date, e.g. "13 Cheshvan 5787" or "י״ג חשוון תשפ״ז".
    func hebrewDateString(in locale: Locale) -> String {
        formatted(Date.FormatStyle(date: .long, time: .omitted, locale: locale, calendar: Calendar(identifier: .hebrew)))
    }
}
