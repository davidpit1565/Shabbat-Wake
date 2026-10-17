import ActivityKit
import Foundation

struct ShabbatWakeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var alarmTitle: String
        var scheduledAt: Date
    }
    var alarmID: String
}
