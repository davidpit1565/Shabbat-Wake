import AppIntents
import Foundation

/// The "Open" button on a ringing alarm. It brings the app forward and asks it to show the wake-up screen.
@available(iOS 26.1, *)
struct OpenWakeScreenIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open"
    static var openAppWhenRun = true

    @Parameter(title: "Alarm")
    var alarmID: String

    @Parameter(title: "Title")
    var alarmTitle: String

    init() {
        alarmID = ""
        alarmTitle = ""
    }

    init(alarmID: String, alarmTitle: String) {
        self.alarmID = alarmID
        self.alarmTitle = alarmTitle
    }

    func perform() async throws -> some IntentResult {
        WakeScreenRequest.save(alarmID: alarmID, title: alarmTitle)
        return .result()
    }
}

/// Handed from the intent to the app through the App Group, because they may run in different processes.
enum WakeScreenRequest {
    private static let idKey = "wakeScreen.alarmID"
    private static let titleKey = "wakeScreen.title"
    private static let dateKey = "wakeScreen.date"
    private static var defaults: UserDefaults { UserDefaults(suiteName: "group.com.shabbatwake.ios") ?? .standard }

    static func save(alarmID: String, title: String) {
        defaults.set(alarmID, forKey: idKey)
        defaults.set(title, forKey: titleKey)
        defaults.set(Date().timeIntervalSince1970, forKey: dateKey)
    }

    /// The request made in the last few minutes, if any. Reading it clears it.
    static func take() -> (alarmID: String, title: String)? {
        defer {
            defaults.removeObject(forKey: idKey)
            defaults.removeObject(forKey: titleKey)
            defaults.removeObject(forKey: dateKey)
        }
        guard let id = defaults.string(forKey: idKey), !id.isEmpty else { return nil }
        let when = defaults.double(forKey: dateKey)
        guard Date().timeIntervalSince1970 - when < 600 else { return nil }
        return (id, defaults.string(forKey: titleKey) ?? "")
    }
}
