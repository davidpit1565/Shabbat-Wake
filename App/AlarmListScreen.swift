import SwiftUI

struct AlarmListScreen: View {
    @ObservedObject var store: AlarmStore
    let onAddAlarm: () -> Void

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
                                        Text(alarm.repeatsWeekly ? "Repeats weekly" : "One-time schedule")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Toggle("Enabled", isOn: Binding(
                                        get: { alarm.isEnabled },
                                        set: { _ in store.toggle(alarm) }
                                    ))
                                    .labelsHidden()
                                    .accessibilityLabel("\(alarm.title), enabled")
                                }
                                .padding(.vertical, 6)
                            }
                            .onDelete(perform: store.delete)
                        } footer: {
                            Text("Saving requests an Apple AlarmKit schedule. The system must accept it, and alarm delivery still requires physical-device verification.")
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

struct ReadinessScreen: View {
    @ObservedObject var store: AlarmStore

    var body: some View {
        NavigationStack {
            List {
                Section("Schedule") {
                    Label("\(store.alarms.count) saved alarm(s)", systemImage: "alarm")
                    Label("\(store.alarms.filter(\.isEnabled).count) enabled in-app schedule(s)", systemImage: "checkmark.circle")
                }
                Section("System checks") {
                    ReadinessRow(title: "System alarm delivery", detail: "AlarmKit scheduling implemented; device verification pending", status: .pending)
                    ReadinessRow(title: "Notification permission", detail: "Not queried yet", status: .pending)
                    ReadinessRow(title: "Location and zmanim", detail: "Not configured", status: .pending)
                    ReadinessRow(title: "Sound assets", detail: "Original tones bundled; system playback unverified", status: .pending)
                }
                Section {
                    Text("This screen intentionally does not show a green 'ready' state while critical capabilities remain unverified.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Readiness")
        }
    }
}

private struct ReadinessRow: View {
    enum Status { case pending }
    let title: String
    let detail: String
    let status: Status

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "minus.circle")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
