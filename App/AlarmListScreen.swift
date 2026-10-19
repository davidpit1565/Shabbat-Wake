import SwiftUI
import UIKit

struct AlarmListScreen: View {
    @ObservedObject var store: AlarmStore
    @ObservedObject var permissions: PermissionGate
    let onAddAlarm: () -> Void
    @Environment(\.locale) private var locale
    @State private var editingAlarm: WakeAlarm?
    @State private var alarmToDelete: WakeAlarm?

    private var permissionState: NativeAlarmKitService.AuthorizationState { permissions.alarm }

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
                                        if let plan = alarm.ringPlan {
                                            Text(plan.count == 1 ? AppLanguage.text("One ring") : String(format: AppLanguage.text("Rings: %d · interval: %d min"), plan.count, plan.intervalMinutes))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
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
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingAlarm = alarm }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction { editingAlarm = alarm }
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        alarmToDelete = alarm
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        editingAlarm = alarm
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        } footer: {
                            Text("Swipe an alarm to edit or delete it, or tap it to edit.")
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
            .sheet(item: $editingAlarm) { alarm in
                AlarmEditorSheet(store: store, editing: alarm)
            }
            .confirmationDialog("Delete this alarm?", isPresented: Binding(get: { alarmToDelete != nil }, set: { if !$0 { alarmToDelete = nil } }), titleVisibility: .visible, presenting: alarmToDelete) { alarm in
                Button("Delete", role: .destructive) { store.delete(alarm) }
                Button("Cancel", role: .cancel) {}
            }
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
