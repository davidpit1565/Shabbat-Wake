import Foundation

/// Data the app shares with its widgets through the App Group container.
struct WidgetSnapshot: Codable, Equatable {
    var alarms: [WakeAlarm] = []
    var latitude: Double?
    var longitude: Double?
    var timeZoneIdentifier: String?
    var placeName: String?
    var times: [ShabbatTimeItem] = []
    /// Whether Pro is unlocked, so Lock Screen widgets can follow it. Nil (older data) counts as unlocked.
    var proUnlocked: Bool?
}

enum SharedStore {
    static let appGroupID = "group.com.shabbatwake.ios"
    private static let key = "shabbatWake.widgetSnapshot.v1"
    private static var defaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    static func update(_ change: (inout WidgetSnapshot) -> Void) {
        var snapshot = load()
        change(&snapshot)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
        }
    }
}
