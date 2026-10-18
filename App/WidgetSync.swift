import Foundation
import WidgetKit

/// Pushes app state into the shared container and asks WidgetKit to refresh.
enum WidgetSync {
    static func updateAlarms(_ alarms: [WakeAlarm]) {
        SharedStore.update { $0.alarms = alarms }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func updateLocation(latitude: Double, longitude: Double, timeZoneIdentifier: String, placeName: String?, times: [ShabbatTimeItem]) {
        SharedStore.update {
            $0.latitude = latitude
            $0.longitude = longitude
            $0.timeZoneIdentifier = timeZoneIdentifier
            $0.placeName = placeName
            $0.times = times
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clearLocation() {
        SharedStore.update {
            $0.latitude = nil
            $0.longitude = nil
            $0.timeZoneIdentifier = nil
            $0.placeName = nil
            $0.times = []
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
