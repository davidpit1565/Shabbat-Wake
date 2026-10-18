import ActivityKit
import CoreLocation
import SwiftUI
import UIKit

struct AlarmListScreen: View {
    @ObservedObject var store: AlarmStore
    let onAddAlarm: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            Group {
                if store.alarms.isEmpty {
                    ContentUnavailableView {
                        Label("No alarms yet", systemImage: "alarm")
                    } description: {
                        Text("Create a wake-up schedule. It will be saved on this device.")
                    } actions: {
                        Button(action: onAddAlarm) {
                            Label("Create alarm", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(store.alarms) { alarm in
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(alarm.timeLabel)
                                            .font(.system(size: 30, weight: .light, design: .rounded))
                                            .monospacedDigit()
                                        Text(alarm.title)
                                            .font(.subheadline.weight(.medium))
                                        if alarm.repeatsWeekly {
                                            Text("Repeats: \(alarm.repeatSummary(locale: locale))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("One-time schedule")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Toggle("Enabled", isOn: Binding(
                                        get: { alarm.isEnabled },
                                        set: { _ in store.toggle(alarm) }
                                    ))
                                    .labelsHidden()
                                    .disabled(store.busyAlarmIDs.contains(alarm.id))
                                    .accessibilityLabel("\(alarm.title), \(alarm.timeLabel)")
                                }
                                .padding(.vertical, 6)
                            }
                            .onDelete(perform: store.delete)
                        } footer: {
                            Text("Alarms are handed to iOS system alarms. Swipe left on an alarm to delete it.")
                        }
                        if let error = store.lastError {
                            Section {
                                Label(error, systemImage: "exclamationmark.triangle.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAddAlarm) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add alarm")
                }
            }
        }
    }
}

/// One line on the Readiness screen, derived from live system state.
struct ReadinessCheck: Identifiable {
    enum Status { case ok, attention, info }
    let id: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let status: Status
}

@MainActor
enum ReadinessEvaluator {
    static func checks(for store: AlarmStore) -> [ReadinessCheck] {
        var rows: [ReadinessCheck] = []
        let enabled = store.alarms.filter(\.isEnabled)

        switch NativeAlarmKitService.authorizationState() {
        case .authorized:
            rows.append(.init(id: "alarm-permission", title: "Alarm permission", detail: "Allowed", status: .ok))
        case .denied:
            rows.append(.init(id: "alarm-permission", title: "Alarm permission", detail: "Denied. Allow alarms for Shabbat Wake in iOS Settings.", status: .attention))
        case .notDetermined:
            rows.append(.init(id: "alarm-permission", title: "Alarm permission", detail: "iOS will ask when you save your first alarm.", status: .info))
        case .unsupported:
            rows.append(.init(id: "alarm-permission", title: "Alarm permission", detail: "System alarms require iOS 26.1 or later.", status: .attention))
        }

        if enabled.isEmpty {
            rows.append(.init(id: "scheduled", title: "Scheduled with iOS", detail: "No enabled alarms.", status: .info))
        } else {
            let confirmed = enabled.filter { store.systemAlarmIDs.contains($0.id) }.count
            if confirmed == enabled.count {
                rows.append(.init(id: "scheduled", title: "Scheduled with iOS", detail: "All enabled alarms are scheduled.", status: .ok))
            } else {
                rows.append(.init(id: "scheduled", title: "Scheduled with iOS", detail: "Some enabled alarms are not scheduled. Open Alarms and switch them off and on again.", status: .attention))
            }
        }

        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            rows.append(.init(id: "location", title: "Location for Shabbat times", detail: "Allowed", status: .ok))
        case .denied, .restricted:
            rows.append(.init(id: "location", title: "Location for Shabbat times", detail: "Not allowed. Shabbat times are unavailable.", status: .attention))
        default:
            rows.append(.init(id: "location", title: "Location for Shabbat times", detail: "Not requested yet. Open the Shabbat times tab.", status: .info))
        }

        if ActivityAuthorizationInfo().areActivitiesEnabled {
            rows.append(.init(id: "live", title: "Live Activities", detail: "Allowed", status: .ok))
        } else {
            rows.append(.init(id: "live", title: "Live Activities", detail: "Off. Alarms still ring; only the Lock Screen card is hidden.", status: .info))
        }

        let soundsPresent = ["GentleChime", "SunriseSequence", "ClassicWake"].allSatisfy {
            Bundle.main.url(forResource: $0, withExtension: "wav") != nil
        }
        rows.append(.init(id: "sounds", title: "Alarm sounds", detail: soundsPresent ? "All sounds are installed." : "Some sounds are missing from this build.", status: soundsPresent ? .ok : .attention))
        return rows
    }

    /// Short state for the home dashboard.
    static func summary(for store: AlarmStore) -> LocalizedStringKey {
        let enabled = store.alarms.filter(\.isEnabled)
        switch NativeAlarmKitService.authorizationState() {
        case .denied, .unsupported: return "Needs attention"
        case .notDetermined: return enabled.isEmpty ? "No alarm yet" : "Needs attention"
        case .authorized:
            if enabled.isEmpty { return "No alarm yet" }
            return enabled.allSatisfy { store.systemAlarmIDs.contains($0.id) } ? "Ready" : "Needs attention"
        }
    }
}

struct ReadinessScreen: View {
    @ObservedObject var store: AlarmStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshToken = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ReadinessEvaluator.checks(for: store)) { check in
                        ReadinessRow(check: check)
                    }
                } footer: {
                    Text("This list reflects what iOS reports right now.")
                }
                Section {
                    Button("Open iOS Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }
            }
            .id(refreshToken)
            .navigationTitle("Readiness")
            .task { await store.refreshFromSystem(); refreshToken += 1 }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.refreshFromSystem(); refreshToken += 1 } }
            }
        }
    }
}

private struct ReadinessRow: View {
    let check: ReadinessCheck

    private var symbol: String {
        switch check.status {
        case .ok: return "checkmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .info: return "minus.circle"
        }
    }
    private var tint: Color {
        switch check.status {
        case .ok: return .green
        case .attention: return .orange
        case .info: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(check.title).font(.subheadline.weight(.medium))
                Text(check.detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}
