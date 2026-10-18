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
    @State private var stopsByItself: Bool
    @State private var plan: RingPlan
    @State private var weeksLimit: Int
    @State private var isSaving = false
    @State private var showPaywall = false
    @EnvironmentObject private var pro: ProStore

    init(store: AlarmStore, editing: WakeAlarm?) {
        self.store = store
        self.editing = editing
        if let alarm = editing {
            _title = State(initialValue: alarm.title)
            _time = State(initialValue: Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: .now) ?? .now)
            _repeatWeekly = State(initialValue: alarm.repeatsWeekly)
            _weekdays = State(initialValue: alarm.weekdays.isEmpty ? [7] : alarm.weekdays)
            _soundID = State(initialValue: alarm.soundID)
            _stopsByItself = State(initialValue: alarm.ringPlan != nil)
            _plan = State(initialValue: alarm.ringPlan ?? .standard)
            _weeksLimit = State(initialValue: alarm.weeksLimit ?? 0)
        } else {
            _title = State(initialValue: AppLanguage.text("Shabbat wake-up"))
            _time = State(initialValue: .now)
            _repeatWeekly = State(initialValue: true)
            _weekdays = State(initialValue: [7])
            _soundID = State(initialValue: "classic")
            _stopsByItself = State(initialValue: true)
            _plan = State(initialValue: .standard)
            _weeksLimit = State(initialValue: 0)
        }
    }

    /// A repeating alarm keeps one scheduled notification per ring and day, so the total has to stay small.
    private var tooManyRings: Bool { stopsByItself && repeatWeekly && weeksLimit == 0 && weekdays.count * plan.count > 30 }
    private var canSave: Bool { !isSaving && (!repeatWeekly || !weekdays.isEmpty) && !tooManyRings }
    private let weekChoices = [0, 4, 8, 12, 26]

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
                if repeatWeekly {
                    Section {
                        Picker(selection: Binding(get: { weeksLimit }, set: { chooseWeeks($0) })) {
                            ForEach(weekChoices, id: \.self) { weeks in
                                Text(weeks == 0 ? AppLanguage.text("Until I turn it off") : String(format: AppLanguage.text("For %d weeks"), weeks)).tag(weeks)
                            }
                        } label: {
                            HStack(spacing: 8) { Text("Repeat for"); if !pro.hasPro { ProBadge() } }
                        }
                    }
                }
                Section {
                    Picker("Ring style", selection: $stopsByItself) {
                        Text("Stops by itself").tag(true)
                        Text("Until I stop it").tag(false)
                    }
                    .pickerStyle(.segmented)
                    if stopsByItself {
                        Stepper(value: $plan.count, in: 1...10) {
                            Text(String(format: AppLanguage.text("Rings: %d"), plan.count))
                        }
                        if plan.count > 1 {
                            Picker("Minutes between rings", selection: $plan.intervalMinutes) {
                                ForEach(RingPlan.intervalChoices, id: \.self) { Text("\($0)").tag($0) }
                            }
                        }
                        Picker("Seconds per ring", selection: $plan.seconds) {
                            ForEach(RingPlan.secondChoices, id: \.self) { Text("\($0)").tag($0) }
                        }
                        Text(summary)
                            .font(.footnote).foregroundStyle(.secondary)
                        if tooManyRings {
                            Text("Too many rings for these days. Lower the number of rings or days.")
                                .font(.footnote).foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("How it rings")
                } footer: {
                    Text(stopsByItself
                         ? "Rings as a notification and stops by itself, even if nobody touches the phone. It follows the silent switch, so keep the phone off silent."
                         : "Apple's system alarm. It rings through silent mode and keeps ringing until it is stopped.")
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
            .sheet(isPresented: $showPaywall) { PaywallView(reason: .weeksAhead) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var summary: String {
        if plan.count == 1 {
            return String(format: AppLanguage.text("Rings once for %d seconds, then stops."), plan.seconds)
        }
        return String(format: AppLanguage.text("Rings %d times, every %d minutes, %d seconds each. Then it stops."), plan.count, plan.intervalMinutes, plan.seconds)
    }

    private func chooseWeeks(_ weeks: Int) {
        if weeks != 0 && !pro.hasPro {
            showPaywall = true
        } else {
            weeksLimit = weeks
        }
    }

    private func save() {
        isSaving = true
        let ringPlan: RingPlan? = stopsByItself ? plan.normalized() : nil
        let weeks: Int? = repeatWeekly && weeksLimit > 0 ? weeksLimit : nil
        Task {
            let saved: Bool
            if let editing {
                saved = await store.update(id: editing.id, title: title, time: time, repeatsWeekly: repeatWeekly, weekdays: weekdays, soundID: soundID, ringPlan: ringPlan, weeksLimit: weeks)
            } else {
                saved = await store.add(title: title, time: time, repeatsWeekly: repeatWeekly, weekdays: weekdays, soundID: soundID, ringPlan: ringPlan, weeksLimit: weeks)
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
