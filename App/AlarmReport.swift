import AlarmKit
import AVFoundation
import UIKit
import UserNotifications

/// A plain-text report of everything that decides whether an alarm rings: the alarms the app holds, the system alarms and
/// notifications iOS really has scheduled, and the permissions. For finding out why an alarm did not ring.
enum AlarmReport {
    static func text() async -> String {
        var lines: [String] = []
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (info?["CFBundleVersion"] as? String ?? "?") + ")"
        lines.append("App \(version), iOS \(UIDevice.current.systemVersion), \(UIDevice.current.model)")
        lines.append("Now \(Date.now.formatted(date: .abbreviated, time: .standard)), \(TimeZone.current.identifier)")
        lines.append("Alarms permission: \(NativeAlarmKitService.authorizationState())")
        lines.append(String(format: "Volume: %.2f", AVAudioSession.sharedInstance().outputVolume))

        let saved = SharedStore.load().alarms
        lines.append("")
        lines.append("Alarms in the app: \(saved.count)")
        for alarm in saved {
            let next = alarm.nextFireDate().map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "none"
            lines.append("- \(alarm.title) \(alarm.hour):\(String(format: "%02d", alarm.minute)) on=\(alarm.isEnabled) mode=\(alarm.isShabbatMode ? "SHABBAT notification" : "system alarm") repeats=\(alarm.repeatsWeekly) days=\(alarm.weekdays.sorted()) sound=\(alarm.soundID) \(alarm.soundSeconds)s rings=\(alarm.ringPlan?.count ?? 1) next=\(next)")
        }

        lines.append("")
        lines.append(contentsOf: NativeAlarmKitService.systemAlarmLines())

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        lines.append("")
        lines.append("Notifications: allowed=\(settings.authorizationStatus.rawValue) (2 = yes) sound=\(settings.soundSetting.rawValue) alert=\(settings.alertSetting.rawValue) lockScreen=\(settings.lockScreenSetting.rawValue) timeSensitive=\(settings.timeSensitiveSetting.rawValue) critical=\(settings.criticalAlertSetting.rawValue) (2 = on)")
        let pending = await center.pendingNotificationRequests()
        lines.append("Pending notifications: \(pending.count)")
        for request in pending.sorted(by: { $0.identifier < $1.identifier }).prefix(15) {
            let next = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate().map { $0.formatted(date: .abbreviated, time: .standard) } ?? "?"
            lines.append("- \(request.content.title) | \(request.content.body) | next \(next) | \(request.identifier.suffix(24))")
        }
        return lines.joined(separator: "\n")
    }
}
