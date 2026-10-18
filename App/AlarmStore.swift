import Foundation
import SwiftUI

@MainActor
final class AlarmStore: ObservableObject {
    @Published private(set) var alarms: [WakeAlarm] = []
    @Published private(set) var lastError: String?
    @Published private(set) var systemAlarmIDs: Set<UUID> = []
    @Published private(set) var busyAlarmIDs: Set<UUID> = []

    private let storageKey = "shabbatWake.localAlarms.v2"

    init() {
        load()
        expireFinishedAlarms()
    }

    /// The enabled alarm that will ring first, with the moment it rings.
    var nextWake: (alarm: WakeAlarm, date: Date)? {
        alarms.compactMap { alarm in alarm.nextFireDate().map { (alarm: alarm, date: $0) } }
            .min { $0.date < $1.date }
    }

    func add(title: String, time: Date, repeatsWeekly: Bool, weekdays: Set<Int>, soundID: String = "classic") async -> Bool {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        var alarm = WakeAlarm(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "Wake-up") : title,
            hour: parts.hour ?? 7,
            minute: parts.minute ?? 0,
            repeatsWeekly: repeatsWeekly,
            weekdays: repeatsWeekly ? weekdays : [],
            soundID: soundID
        )
        do {
            try await NativeAlarmKitService.schedule(alarm)
            systemAlarmIDs.insert(alarm.id)
            alarm.isEnabled = true
            alarm.armedAt = .now
            alarms.append(alarm)
            LiveActivityManager.start(for: alarm)
            save()
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func toggle(_ alarm: WakeAlarm) {
        guard let current = alarms.first(where: { $0.id == alarm.id }) else { return }
        let alarmID = current.id
        guard !busyAlarmIDs.contains(alarmID) else { return }
        let shouldEnable = !current.isEnabled
        busyAlarmIDs.insert(alarmID)
        Task {
            defer { busyAlarmIDs.remove(alarmID) }
            do {
                if shouldEnable {
                    guard let latest = alarms.first(where: { $0.id == alarmID }) else { return }
                    try await NativeAlarmKitService.schedule(latest)
                    systemAlarmIDs.insert(alarmID)
                } else {
                    try await NativeAlarmKitService.cancel(id: alarmID)
                    systemAlarmIDs.remove(alarmID)
                    LiveActivityManager.end(alarmID: alarmID)
                }
                guard let index = alarms.firstIndex(where: { $0.id == alarmID }) else {
                    // If the local record disappeared while scheduling, clean up any system alarm.
                    if shouldEnable { try? await NativeAlarmKitService.cancel(id: alarmID) }
                    return
                }
                alarms[index].isEnabled = shouldEnable
                if shouldEnable {
                    alarms[index].armedAt = .now
                    LiveActivityManager.start(for: alarms[index])
                }
                save()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func delete(at offsets: IndexSet) {
        let targets = offsets.map { alarms[$0] }
        for alarm in targets { delete(alarm) }
    }

    func delete(_ alarm: WakeAlarm) {
        guard !busyAlarmIDs.contains(alarm.id) else { return }
        busyAlarmIDs.insert(alarm.id)
        Task {
            defer { busyAlarmIDs.remove(alarm.id) }
            do {
                try await NativeAlarmKitService.cancel(id: alarm.id)
                systemAlarmIDs.remove(alarm.id)
                alarms.removeAll { $0.id == alarm.id }
                LiveActivityManager.end(alarmID: alarm.id)
                save()
                lastError = nil
            } catch {
                // Keep the local record visible if cancellation failed; do not hide a possibly active alarm.
                lastError = error.localizedDescription
            }
        }
    }

    func clearError() { lastError = nil }

    func requestSystemAlarmPermission() async -> Bool {
        do {
            let allowed = try await NativeAlarmKitService.requestAuthorization()
            lastError = allowed ? nil : String(localized: "Alarm permission was not granted.")
            return allowed
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Compares saved alarms with what iOS actually has scheduled. Call whenever the app becomes active.
    func refreshFromSystem() async {
        expireFinishedAlarms()
        guard let scheduled = try? NativeAlarmKitService.scheduledAlarmIDs() else { return }
        systemAlarmIDs = scheduled
        guard NativeAlarmKitService.authorizationState() == .authorized else { return }
        // Weekly alarms that iOS no longer knows about (for example after restoring a backup) are scheduled again.
        let missing = alarms.filter { $0.isEnabled && $0.repeatsWeekly && !scheduled.contains($0.id) && !busyAlarmIDs.contains($0.id) }
        for alarm in missing {
            do {
                try await NativeAlarmKitService.schedule(alarm)
                systemAlarmIDs.insert(alarm.id)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    /// One-time alarms switch themselves off once they have rung.
    private func expireFinishedAlarms() {
        var changed = false
        for index in alarms.indices where alarms[index].isEnabled && alarms[index].nextFireDate() == nil {
            alarms[index].isEnabled = false
            systemAlarmIDs.remove(alarms[index].id)
            changed = true
        }
        if changed { save() } else { WidgetSync.updateAlarms(alarms) }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do { alarms = try JSONDecoder().decode([WakeAlarm].self, from: data) }
        catch { lastError = String(localized: "Saved alarms could not be read.") }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(alarms)
            UserDefaults.standard.set(data, forKey: storageKey)
            lastError = nil
        } catch {
            lastError = String(localized: "Alarm changes could not be saved.")
        }
        WidgetSync.updateAlarms(alarms)
    }
}
