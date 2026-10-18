import SwiftUI
import UIKit

struct RemindersScreen: View {
    @ObservedObject var store: ReminderStore
    @EnvironmentObject private var pro: ProStore
    @Environment(\.locale) private var locale
    @State private var paywall: PaywallReason?
    @State private var editing: ShabbatReminder?
    @State private var adding = false

    private var hasTimes: Bool { SharedStore.load().times.contains { $0.category == "candles" } }

    var body: some View {
        List {
            Section {
                if store.reminders.isEmpty {
                    Text("No reminders yet.").foregroundStyle(.secondary)
                }
                ForEach(store.reminders) { reminder in
                    Button { edit(reminder) } label: {
                        HStack {
                            Text(label(reminder.minutesBefore))
                            Spacer()
                            ProBadge()
                        }
                        .foregroundStyle(.primary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { Task { await store.delete(id: reminder.id) } } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
                Button { addTapped() } label: {
                    HStack {
                        Label("Add a reminder", systemImage: "plus")
                        Spacer()
                        if store.reminders.count >= ProPolicy.freeReminderLimit { ProBadge() }
                    }
                }
            } header: {
                Text("Before candle lighting")
            } footer: {
                Text("You get a notification before candle lighting, using the times saved for your location.")
            }
            if store.notificationsDenied {
                Section {
                    Text("Notifications are turned off for this app, so reminders cannot appear.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }
            }
            if !store.reminders.isEmpty && !hasTimes {
                Section {
                    Text("Open Shabbat times once and allow location, so reminders know when candle lighting is.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Reminders")
        .sheet(item: $paywall) { PaywallView(reason: $0) }
        .sheet(item: $editing) { reminder in
            ReminderTimeSheet(initial: reminder.minutesBefore) { minutes in
                Task { await store.update(id: reminder.id, minutesBefore: minutes) }
            }
        }
        .sheet(isPresented: $adding) {
            ReminderTimeSheet(initial: ProPolicy.defaultReminderMinutes) { minutes in
                Task { await store.add(minutesBefore: minutes) }
            }
        }
        .task { await store.reschedule() }
    }

    private func label(_ minutes: Int) -> String {
        String(format: AppLanguage.text("%d minutes before candle lighting"), minutes)
    }

    private func addTapped() {
        guard ProPolicy.canAddReminder(currentCount: store.reminders.count, hasPro: pro.hasPro) else {
            paywall = store.reminders.count >= ProPolicy.maxReminders && pro.hasPro ? nil : .moreReminders
            return
        }
        if pro.hasPro {
            adding = true
        } else {
            Task { await store.add(minutesBefore: ProPolicy.defaultReminderMinutes) }
        }
    }

    private func edit(_ reminder: ShabbatReminder) {
        if ProPolicy.canChooseReminderTime(hasPro: pro.hasPro) {
            editing = reminder
        } else {
            paywall = .reminderTime
        }
    }
}

extension PaywallReason: Identifiable {
    var id: String { String(describing: self) }
}

private struct ReminderTimeSheet: View {
    @State var selection: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    init(initial: Int, onSave: @escaping (Int) -> Void) {
        _selection = State(initialValue: ProPolicy.reminderChoices.contains(initial) ? initial : ProPolicy.defaultReminderMinutes)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Minutes before candle lighting", selection: $selection) {
                    ForEach(ProPolicy.reminderChoices, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(selection); dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
