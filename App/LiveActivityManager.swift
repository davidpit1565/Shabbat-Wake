import ActivityKit
import Foundation

@MainActor
enum LiveActivityManager {
    static func start(for alarm: WakeAlarm) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = alarm.hour
        components.minute = alarm.minute
        components.second = 0
        var scheduled = Calendar.current.date(from: components) ?? now
        if scheduled <= now {
            scheduled = Calendar.current.date(byAdding: .day, value: 1, to: scheduled) ?? scheduled
        }
        let attributes = ShabbatWakeActivityAttributes(alarmID: alarm.id.uuidString)
        let state = ShabbatWakeActivityAttributes.ContentState(
            alarmTitle: alarm.title,
            scheduledAt: scheduled
        )
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: scheduled),
                pushType: nil
            )
        } catch {
            // AlarmKit scheduling remains authoritative if a Live Activity cannot start.
        }
    }
}
