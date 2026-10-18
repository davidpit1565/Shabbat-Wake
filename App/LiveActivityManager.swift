import ActivityKit
import Foundation

@MainActor
enum LiveActivityManager {
    /// Shows a Live Activity for an alarm that rings within the next few hours.
    static func start(for alarm: WakeAlarm) {
        end(alarmID: alarm.id)
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let scheduled = alarm.nextFireDate(),
              scheduled.timeIntervalSinceNow <= 8 * 60 * 60 else { return }
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

    static func end(alarmID: UUID) {
        let id = alarmID.uuidString
        for activity in Activity<ShabbatWakeActivityAttributes>.activities where activity.attributes.alarmID == id {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
