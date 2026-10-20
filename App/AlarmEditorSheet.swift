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
    @State private var ringSeconds: Int
    @State private var showSystemSoundConfirm = false
    @State private var systemSoundConfirmed = false
    @State private var shabbatMode: Bool
    @State private var showModeConfirm = false
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
            _ringSeconds = State(initialValue: alarm.soundSeconds)
            _systemSoundConfirmed = State(initialValue: alarm.soundID == "system")
            _shabbatMode = State(initialValue: alarm.isShabbatMode)
        } else {
            _title = State(initialValue: AppLanguage.text("Shabbat wake-up"))
            _time = State(initialValue: .now)
            _repeatWeekly = State(initialValue: true)
            _weekdays = State(initialValue: [7])
            _soundID = State(initialValue: "classic")
            _stopsByItself = State(initialValue: true)
            _plan = State(initialValue: .standard)
            _weeksLimit = State(initialValue: 0)
            _ringSeconds = State(initialValue: RingPlan.defaultLength)
            // A new alarm starts as a Shabbat alarm: the app is made for Shabbat.
            _shabbatMode = State(initialValue: true)
        }
    }

    /// A repeating alarm keeps one scheduled notification per ring and day, so the total has to stay small.
    private var tooManyRings: Bool { stopsByItself && repeatWeekly && weeksLimit == 0 && weekdays.count * plan.count > 30 }
    private var canSave: Bool { !isSaving && (!repeatWeekly || !weekdays.isEmpty) && !tooManyRings }
    private let weekChoices = [0, 4, 8, 12, 26]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Shabbat alarm", isOn: $shabbatMode)
                } footer: {
                    Text(LocalizedStringKey(shabbatMode
                         ? "A Shabbat alarm is an ordinary notification with no buttons. Its sound and vibration stop by themselves after the time you choose. It does not sound if the silent switch on the side of the iPhone is on."
                         : "A regular alarm is an Apple system alarm with Stop and Open buttons. It also rings when the iPhone is on silent, and the vibration continues until you press Stop."))
                }
                Section("Alarm details") {
                    TextField("Alarm name", text: $title)
                    HStack {
                        Text("Time")
                        Spacer()
                        // Hours then minutes, left to right, in every language, as the digits are read.
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    Toggle("Repeat weekly", isOn: $repeatWeekly)
                    if repeatWeekly {
                        WeekdayPicker(selection: $weekdays, locale: locale)
                    }
                    Picker("Alarm sound", selection: $soundID) {
                        Text("Gentle Chime").tag("gentle")
                        Text("Sunrise Sequence").tag("sunrise")
                        Text("Classic Wake").tag("classic")
                        if !shabbatMode { Text("Apple's standard alarm sound").tag("system") }
                    }
                    if soundID == "system" && !shabbatMode {
                        Text("Apple's standard sound cannot stop by itself. It rings until you press Stop.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Picker("How long each ring sounds", selection: $ringSeconds) {
                            ForEach(RingPlan.lengthChoices, id: \.self) { Text(String(format: AppLanguage.text("%d seconds"), $0)).tag($0) }
                        }
                    }
                }
                if repeatWeekly {
                    Section {
                        Picker(selection: Binding(get: { weeksLimit }, set: { chooseWeeks($0) })) {
                            ForEach(weekChoices, id: \.self) { weeks in
                                Text(weeks == 0 ? AppLanguage.text("Until I turn it off") : String(format: AppLanguage.text("For %d weeks"), weeks) + " · PRO").tag(weeks)
                            }
                        } label: {
                            Text("Repeat for")
                        }
                    }
                }
                Section {
                    Picker("Ring style", selection: $stopsByItself) {
                        Text("Several rings").tag(true)
                        Text("One ring").tag(false)
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
                    Text(LocalizedStringKey(shabbatMode
                         ? "Each ring is a notification that stops by itself after the length you chose. The next ring comes after the minutes you set."
                         : stopsByItself
                         ? "Each ring is a real Apple alarm. It sounds through silent mode and Focus for the length you chose, with no snooze. The next ring comes after the minutes you set."
                         : "Apple's system alarm. It sounds through silent mode and Focus for the length you chose, once, with no snooze."))
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
            .onChange(of: shabbatMode) { _, on in
                if on && soundID == "system" { soundID = "classic" }
            }
            .onChange(of: soundID) { old, new in
                // Apple's standard sound never stops by itself, so ask once before it is chosen.
                if new == "system" && !systemSoundConfirmed {
                    soundID = old
                    showSystemSoundConfirm = true
                }
            }
            .alert(LocalizedStringKey(shabbatMode ? "Save as a Shabbat alarm?" : "Save as a regular alarm?"), isPresented: $showModeConfirm) {
                Button(LocalizedStringKey(shabbatMode ? "Keep Shabbat alarm" : "Keep regular alarm")) { save() }
                Button(LocalizedStringKey(shabbatMode ? "Make it a regular alarm" : "Make it a Shabbat alarm")) {
                    shabbatMode.toggle()
                    save()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey(shabbatMode
                     ? "It will stop by itself with no buttons, and will not sound if the iPhone's silent switch is on."
                     : "It is an Apple system alarm with Stop and Open buttons. It rings even on silent and vibrates until you stop it."))
            }
            .alert("Apple's standard alarm sound", isPresented: $showSystemSoundConfirm) {
                Button("Use it anyway") {
                    systemSoundConfirmed = true
                    soundID = "system"
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It rings until you press Stop. It will not stop by itself, on Shabbat too. Our own sounds stop by themselves.")
            }
            .sheet(isPresented: $showPaywall) { PaywallView(reason: .weeksAhead) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if editing == nil { showModeConfirm = true } else { save() }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var summary: String {
        if plan.count == 1 {
            return AppLanguage.text("Rings once, until you stop it.")
        }
        return String(format: AppLanguage.text("Rings: %d · interval: %d min. Stop each ring when it sounds."), plan.count, plan.intervalMinutes)
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
                saved = await store.update(id: editing.id, title: title, time: time, repeatsWeekly: repeatWeekly, weekdays: weekdays, soundID: soundID, ringPlan: ringPlan, weeksLimit: weeks, ringSeconds: ringSeconds, shabbatMode: shabbatMode)
            } else {
                saved = await store.add(title: title, time: time, repeatsWeekly: repeatWeekly, weekdays: weekdays, soundID: soundID, ringPlan: ringPlan, weeksLimit: weeks, ringSeconds: ringSeconds, shabbatMode: shabbatMode)
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
                            .frame(maxWidth: .infinity, minHeight: 44)
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
