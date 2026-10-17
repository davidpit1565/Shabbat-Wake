import Foundation
import SwiftUI

struct WakeAlarm: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var hour: Int
    var minute: Int
    var repeatsWeekly: Bool
    var weekdays: Set<Int>
    var isEnabled: Bool = true
    var soundID: String = "classic"
    var createdAt: Date = .now

    var timeLabel: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

@MainActor
final class AlarmStore: ObservableObject {
    @Published private(set) var alarms: [WakeAlarm] = []
    @Published private(set) var lastError: String?
    @Published private(set) var systemAlarmIDs: Set<UUID> = []

    private let storageKey = "shabbatWake.localAlarms.v2"

    init() { load() }

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
            LiveActivityManager.start(for: alarm)
            alarm.isEnabled = true
            alarms.append(alarm)
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
        let shouldEnable = !current.isEnabled
        Task {
            do {
                if shouldEnable {
                    guard let latest = alarms.first(where: { $0.id == alarmID }) else { return }
                    try await NativeAlarmKitService.schedule(latest)
                    systemAlarmIDs.insert(alarmID)
                } else {
                    try await NativeAlarmKitService.cancel(id: alarmID)
                    systemAlarmIDs.remove(alarmID)
                }
                guard let index = alarms.firstIndex(where: { $0.id == alarmID }) else {
                    // If the local record disappeared while scheduling, clean up any system alarm.
                    if shouldEnable { try? await NativeAlarmKitService.cancel(id: alarmID) }
                    return
                }
                alarms[index].isEnabled = shouldEnable
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
        Task {
            do {
                try await NativeAlarmKitService.cancel(id: alarm.id)
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
    }
}
