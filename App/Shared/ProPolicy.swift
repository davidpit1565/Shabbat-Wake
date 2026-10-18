import Foundation

/// What is free and what needs Pro, kept free of StoreKit so it can be tested.
enum ProPolicy {
    /// Candle-lighting reminders a free user can have, and the fixed time before candle lighting they use.
    static let freeReminderLimit = 1
    static let defaultReminderMinutes = 30
    static let maxReminders = 4

    /// Minutes before candle lighting a Pro user can choose from.
    static let reminderChoices = [10, 15, 18, 20, 30, 40, 45, 60, 90, 120]

    /// Saved places besides the current location: none for free, several for Pro.
    static let maxSavedPlaces = 10

    static func canSavePlace(currentCount: Int, hasPro: Bool) -> Bool {
        hasPro && currentCount < maxSavedPlaces
    }

    static func canAddReminder(currentCount: Int, hasPro: Bool) -> Bool {
        hasPro ? currentCount < maxReminders : currentCount < freeReminderLimit
    }

    static func canChooseReminderTime(hasPro: Bool) -> Bool { hasPro }
}
