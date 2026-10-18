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

    func add(title: String, time: Date, repeatsWeekly: Bool, weekdays: Set<Int>, soundID: String = "classic", ringPlan: RingPlan? = nil, weeksLimit: Int? = nil) async -> Bool {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        var alarm = WakeAlarm(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppLanguage.text("Wake-up") : title,
            hour: parts.hour ?? 7,
            minute: parts.minute ?? 0,
            repeatsWeekly: repeatsWeekly,
            weekdays: repeatsWeekly ? weekdays : [],
            soundID: soundID,
            ringPlan: ringPlan?.normalized(),
            weeksLimit: repeatsWeekly ? weeksLimit : nil
        )
        alarm.armedAt = .now
        do {
            try await AlarmScheduler.schedule(alarm)
            systemAlarmIDs.insert(alarm.id)
            alarm.isEnabled = true
            alarm.armedAt = .now
            alarms.append(alarm)
            save()
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Changes an existing alarm. The system alarm is replaced; if the new one cannot be scheduled the old one is put back.
    func update(id: UUID, title: String, time: Date, repeatsWeekly: Bool, weekdays: Set<Int>, soundID: String, ringPlan: RingPlan? = nil, weeksLimit: Int? = nil) async -> Bool {
        guard let index = alarms.firstIndex(where: { $0.id == id }), !busyAlarmIDs.contains(id) else { return false }
        busyAlarmIDs.insert(id)
        defer { busyAlarmIDs.remove(id) }
        let previous = alarms[index]
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        var updated = previous
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppLanguage.text("Wake-up") : title
        updated.hour = parts.hour ?? previous.hour
        updated.minute = parts.minute ?? previous.minute
        updated.repeatsWeekly = repeatsWeekly
        updated.weekdays = repeatsWeekly ? weekdays : []
        updated.soundID = soundID
        updated.ringPlan = ringPlan?.normalized()
        updated.weeksLimit = repeatsWeekly ? weeksLimit : nil
        updated.isEnabled = true
        updated.armedAt = .now
        do {
            try? await AlarmScheduler.cancel(previous)
            try await AlarmScheduler.schedule(updated)
            systemAlarmIDs.insert(id)
            if let current = alarms.firstIndex(where: { $0.id == id }) { alarms[current] = updated }
            save()
            lastError = nil
            return true
        } catch {
            if previous.isEnabled { try? await AlarmScheduler.schedule(previous) }
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
                    guard var latest = alarms.first(where: { $0.id == alarmID }) else { return }
                    latest.isEnabled = true
                    latest.armedAt = .now
                    try await AlarmScheduler.schedule(latest)
                    systemAlarmIDs.insert(alarmID)
                } else {
                    try await AlarmScheduler.cancel(current)
                    systemAlarmIDs.remove(alarmID)
                }
                guard let index = alarms.firstIndex(where: { $0.id == alarmID }) else {
                    // If the local record disappeared while scheduling, clean up any system alarm.
                    if shouldEnable { try? await AlarmScheduler.cancel(current) }
                    return
                }
                alarms[index].isEnabled = shouldEnable
                if shouldEnable {
                    alarms[index].armedAt = .now
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
                try await AlarmScheduler.cancel(alarm)
                systemAlarmIDs.remove(alarm.id)
                alarms.removeAll { $0.id == alarm.id }
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
            lastError = allowed ? nil : AppLanguage.text("Alarm permission was not granted.")
            return allowed
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Compares saved alarms with what iOS actually has scheduled. Call whenever the app becomes active.
    func refreshFromSystem() async {
        if ScreenshotMode.isOn { return }
        expireFinishedAlarms()
        let (scheduledOrNil, state) = await Task.detached(priority: .userInitiated) {
            (try? NativeAlarmKitService.scheduledAlarmIDs(), NativeAlarmKitService.authorizationState())
        }.value
        // Shabbat alarms are notifications; schedule them again so later weeks and repeats stay covered.
        for alarm in alarms where alarm.isEnabled && alarm.ringPlan != nil && !busyAlarmIDs.contains(alarm.id) && alarm.nextFireDate() != nil {
            do { try await ShabbatAlarmService.schedule(alarm) } catch { lastError = error.localizedDescription }
        }
        let ringIDs = await ShabbatAlarmService.pendingAlarmIDs()
        systemAlarmIDs = (scheduledOrNil ?? []).union(ringIDs)
        guard let scheduled = scheduledOrNil, state == .authorized else { return }
        // Weekly alarms that iOS no longer knows about (for example after restoring a backup) are scheduled again.
        let missing = alarms.filter { $0.isEnabled && $0.ringPlan == nil && $0.repeatsWeekly && !scheduled.contains($0.id) && !busyAlarmIDs.contains($0.id) }
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
        if ScreenshotMode.isOn { alarms = ScreenshotMode.sampleAlarms; return }
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do { alarms = try JSONDecoder().decode([WakeAlarm].self, from: data) }
        catch { lastError = AppLanguage.text("Saved alarms could not be read.") }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(alarms)
            UserDefaults.standard.set(data, forKey: storageKey)
            lastError = nil
        } catch {
            lastError = AppLanguage.text("Alarm changes could not be saved.")
        }
        WidgetSync.updateAlarms(alarms)
    }
}
