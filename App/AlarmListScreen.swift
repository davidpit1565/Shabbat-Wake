import SwiftUI
import UIKit

struct AlarmListScreen: View {
    @ObservedObject var store: AlarmStore
    let onAddAlarm: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var permissionRefresh = 0

    private var permissionState: NativeAlarmKitService.AuthorizationState {
        _ = permissionRefresh
        return NativeAlarmKitService.authorizationState()
    }

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
                        if permissionState == .denied || permissionState == .unsupported {
                            Section {
                                Label(permissionState == .denied ? "Alarms are turned off for this app." : "System alarms require iOS 26.1 or later.", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                if permissionState == .denied {
                                    Button("Open Settings") {
                                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }
                        }
                        Section {
                            ForEach(store.alarms) { alarm in
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(alarm.timeLabel(in: locale))
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
                                    .accessibilityLabel("\(alarm.title), \(alarm.timeLabel(in: locale))")
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
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { permissionRefresh += 1 }
            }
        }
    }
}
