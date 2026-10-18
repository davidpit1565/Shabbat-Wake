import Foundation

/// Used only by the automated App Store screenshots: `-screenshotMode` fills the app with two sample
/// alarms and skips the permission sheet. Without that launch argument nothing here has any effect.
enum ScreenshotMode {
    static let isOn = CommandLine.arguments.contains("-screenshotMode")

    static var sampleAlarms: [WakeAlarm] {
        var shabbat = WakeAlarm(title: AppLanguage.text("Shabbat alarm"), hour: 7, minute: 30,
                                repeatsWeekly: true, weekdays: [7], ringPlan: .standard)
        shabbat.armedAt = .now
        var weekday = WakeAlarm(title: AppLanguage.text("Wake-up"), hour: 6, minute: 45,
                                repeatsWeekly: true, weekdays: [1, 2, 3, 4, 5])
        weekday.armedAt = .now
        return [shabbat, weekday]
    }
}
