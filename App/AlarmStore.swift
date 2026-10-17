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

    private let storageKey = "shabbatWake.localAlarms.v1"

    init() { load() }

    func add(title: String, time: Date, repeatsWeekly: Bool, weekdays: Set<Int>) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let alarm = WakeAlarm(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Wake-up" : title,
            hour: parts.hour ?? 7,
            minute: parts.minute ?? 0,
            repeatsWeekly: repeatsWeekly,
            weekdays: repeatsWeekly ? weekdays : []
        )
        alarms.append(alarm)
        save()
    }

    func toggle(_ alarm: WakeAlarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index].isEnabled.toggle()
        save()
    }

    func delete(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
        save()
    }

    func delete(_ alarm: WakeAlarm) {
        alarms.removeAll { $0.id == alarm.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do { alarms = try JSONDecoder().decode([WakeAlarm].self, from: data) }
        catch { lastError = "Saved alarms could not be read." }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(alarms)
            UserDefaults.standard.set(data, forKey: storageKey)
            lastError = nil
        } catch {
            lastError = "Alarm changes could not be saved."
        }
    }
}
