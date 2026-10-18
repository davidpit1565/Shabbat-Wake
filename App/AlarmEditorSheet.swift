import SwiftUI

/// Creates a new alarm, or edits an existing one when `editing` is set.
struct AlarmEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @ObservedObject var store: AlarmStore
    let editing: WakeAlarm?

    @State private var title: String
    @State private var time: Date
    @State private var repeatWeekly: Bool
    @State private var weekdays: Set<Int>
    @State private var soundID: String
    @State private var isSaving = false

    init(store: AlarmStore, editing: WakeAlarm?) {
        self.store = store
        self.editing = editing
        if let alarm = editing {
            _title = State(initialValue: alarm.title)
            _time = State(initialValue: Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: .now) ?? .now)
            _repeatWeekly = State(initialValue: alarm.repeatsWeekly)
            _weekdays = State(initialValue: alarm.weekdays.isEmpty ? [7] : alarm.weekdays)
            _soundID = State(initialValue: alarm.soundID)
        } else {
            _title = State(initialValue: AppLanguage.text("Shabbat wake-up"))
            _time = State(initialValue: .now)
            _repeatWeekly = State(initialValue: true)
            _weekdays = State(initialValue: [7])
            _soundID = State(initialValue: "classic")
        }
    }

    private var canSave: Bool { !isSaving && (!repeatWeekly || !weekdays.isEmpty) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Alarm details") {
                    TextField("Alarm name", text: $title)
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    Toggle("Repeat weekly", isOn: $repeatWeekly)
                    if repeatWeekly {
                        WeekdayPicker(selection: $weekdays, locale: locale)
                    }
                    Picker("Alarm sound", selection: $soundID) {
                        Text("Gentle Chime").tag("gentle")
                        Text("Sunrise Sequence").tag("sunrise")
                        Text("Classic Wake").tag("classic")
                    }
                }
                Section {
                    Text("Saving requests an Apple system alarm. The alarm will be saved only if iOS grants permission and scheduling succeeds.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error = store.lastError {
                    Section("Could not schedule alarm") {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(editing == nil ? "New alarm" : "Edit alarm")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { store.clearError() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let saved: Bool
            if let editing {
                saved = await store.update(id: editing.id, title: title, time: time, repeatsWeekly: repeatWeekly, weekdays: weekdays, soundID: soundID)
            } else {
                saved = await store.add(title: title, time: time, repeatsWeekly: repeatWeekly, weekdays: weekdays, soundID: soundID)
            }
            isSaving = false
            if saved { dismiss() }
        }
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    let locale: Locale

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    let isOn = selection.contains(day)
                    Button {
                        if isOn { selection.remove(day) } else { selection.insert(day) }
                    } label: {
                        Text(calendar.veryShortWeekdaySymbols[day - 1])
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(isOn ? Color.accentColor : Color.secondary.opacity(0.15), in: Circle())
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(calendar.weekdaySymbols[day - 1])
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            if selection.isEmpty {
                Text("Choose at least one day.")
                    .font(.footnote).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
