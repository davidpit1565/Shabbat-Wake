import SwiftUI
import UserNotifications

@main
struct ShabbatWakeApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        AppLanguage.applyDirection(for: AppLanguage.effectiveCode(for: AppLanguage.preference))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(preferredColorScheme)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

/// The ring gives a little when pressed, with a light tap.
private struct RingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

private enum WakePalette {
    static let blue = Color(red: 0, green: 92 / 255, blue: 230 / 255)
    static let cyan = Color(red: 89 / 255, green: 230 / 255, blue: 1)
    static let silver = Color(red: 201 / 255, green: 216 / 255, blue: 236 / 255)
}

private enum MainTab: String, CaseIterable, Identifiable {
    case home, alarms, times, settings
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .alarms: "Alarms"
        case .times: "Shabbat times"
        case .settings: "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .home: "house"
        case .alarms: "alarm"
        case .times: "calendar"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @State private var selectedTab: MainTab = .home
    @State private var showAddAlarm = false
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var permissions = PermissionGate()
    @StateObject private var pro = ProStore()
    @StateObject private var reminders = ReminderStore()
    @State private var browserLink: InAppLink?
    @AppStorage("preferredLanguage") private var preferredLanguage = "system"
    @AppStorage(TimeFormat.storageKey) private var timeFormat = "system"
    @State private var editingAlarm: WakeAlarm?
    @State private var wakeRequest: WakeRequest?
    @Environment(\.scenePhase) private var scenePhase

    private var languageCode: String { AppLanguage.effectiveCode(for: preferredLanguage) }

    /// The "Open" button on a ringing alarm leaves a note; show the wake-up screen for it.
    private func showWakeScreenIfRequested() {
        guard let note = WakeScreenRequest.take() else { return }
        wakeRequest = WakeRequest(alarmID: UUID(uuidString: note.alarmID), title: note.title)
    }

    var body: some View {
        // Set before the views below are created, so navigation and tab bars pick up the right direction.
        let _ = AppLanguage.applyDirection(for: languageCode)
        TabView(selection: $selectedTab) {
            HomeDashboard(alarmStore: alarmStore, onAddAlarm: { showAddAlarm = true }, onOpenTimes: { selectedTab = .times }, onOpenAlarm: openNextAlarm, onEditAlarm: { editingAlarm = $0 })
                .tabItem { Label(MainTab.home.title, systemImage: MainTab.home.symbol) }
                .tag(MainTab.home)
            AlarmListScreen(store: alarmStore, permissions: permissions, onAddAlarm: { showAddAlarm = true })
                .tabItem { Label(MainTab.alarms.title, systemImage: MainTab.alarms.symbol) }
                .tag(MainTab.alarms)
            ShabbatTimesScreen()
                .tabItem { Label(MainTab.times.title, systemImage: MainTab.times.symbol) }
                .tag(MainTab.times)
            SettingsScreen(reminders: reminders)
                .tabItem { Label(MainTab.settings.title, systemImage: MainTab.settings.symbol) }
                .tag(MainTab.settings)
        }
        .tint(WakePalette.blue)
        .id(languageCode)
        .sheet(isPresented: $showAddAlarm) { AlarmEditorSheet(store: alarmStore, editing: nil) }
        .sheet(item: $editingAlarm) { AlarmEditorSheet(store: alarmStore, editing: $0) }
        .sheet(isPresented: $permissions.isPresented) { PermissionsSheet(gate: permissions) }
        .sheet(item: $browserLink) { InAppBrowser(url: $0.url).ignoresSafeArea() }
        .fullScreenCover(item: $wakeRequest) { request in
            WakeScreen(request: request) { wakeRequest = nil }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { showWakeScreenIfRequested() }
        }
        .onAppear { showWakeScreenIfRequested() }
        // Applied after the sheets so the sheets receive them too. A sheet only inherits what is set outside it.
        .environmentObject(pro)
        .environment(\.locale, TimeFormat.locale(language: languageCode, format: timeFormat))
        .environment(\.layoutDirection, AppLanguage.isRightToLeft(languageCode) ? .rightToLeft : .leftToRight)
        .environment(\.openURL, OpenURLAction { url in
            // Web links open inside the app; anything else (mail, settings) goes to the system.
            guard url.scheme == "https" || url.scheme == "http" else { return .systemAction }
            browserLink = InAppLink(url: url)
            return .handled
        })
        .task {
            await ShabbatAlarmService.clearLegacyNotificationRings()
            if !ScreenshotMode.isOn { await permissions.checkOnLaunch() }
            await alarmStore.refreshFromSystem()
            WatchSync.shared.start()
            WidgetSync.updateLanguage(languageCode)
            WidgetSync.updateTimeFormat(timeFormat)
            await pro.start()
            await TimesRefresher.refreshIfNeeded()
            await reminders.reschedule()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shabbatTimesUpdated)) { _ in
            Task { await reminders.reschedule() }
        }
        .onChange(of: timeFormat) { _, format in
            WidgetSync.updateTimeFormat(format)
            Task { await reminders.reschedule() }
        }
        .onChange(of: languageCode) { _, code in
            WidgetSync.updateLanguage(code)
            Task {
                await reminders.reschedule()
                await TimesRefresher.refreshForLanguage()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                permissions.refresh()
                Task { await alarmStore.refreshFromSystem() }
            }
        }
    }
}

extension RootView {
    /// Tapping the ring opens the alarm that rings next, in the Alarms tab; with no alarm it starts a new one.
    func openNextAlarm() {
        if let alarm = alarmStore.nextWake?.alarm {
            selectedTab = .alarms
            editingAlarm = alarm
        } else {
            showAddAlarm = true
        }
    }
}

struct HomeDashboard: View {
    @ObservedObject var alarmStore: AlarmStore
    var onAddAlarm: () -> Void
    var onOpenTimes: () -> Void
    var onOpenAlarm: () -> Void
    var onEditAlarm: (WakeAlarm) -> Void
    @Environment(\.locale) private var locale

    @State private var nextShabbatTime: ShabbatTimeItem?
    @State private var shabbatZone: TimeZone?
    @State private var nextTitle: String?

    /// The alarm that rings first comes first; switched-off alarms follow.
    private var orderedAlarms: [WakeAlarm] {
        alarmStore.alarms.sorted { a, b in
            switch (a.isEnabled ? a.nextFireDate() : nil, b.isEnabled ? b.nextFireDate() : nil) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.hour * 60 + a.minute < b.hour * 60 + b.minute
            }
        }
    }

    private func alarmRow(_ alarm: WakeAlarm) -> some View {
        HStack(spacing: 12) {
            Button { onEditAlarm(alarm) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(alarm.timeLabel(in: locale))
                        .font(.system(size: 26, weight: .light, design: .rounded)).monospacedDigit()
                    Text(alarm.title).font(.subheadline.weight(.medium))
                    Text(alarm.repeatsWeekly ? alarm.repeatSummary(locale: locale) : AppLanguage.text("One-time schedule"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Toggle("Enabled", isOn: Binding(get: { alarm.isEnabled }, set: { _ in alarmStore.toggle(alarm) }))
                .labelsHidden()
                .disabled(alarmStore.busyAlarmIDs.contains(alarm.id))
                .accessibilityLabel("\(alarm.title), \(alarm.timeLabel(in: locale))")
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var nextAlarmTime: String {
        guard let date = alarmStore.nextWake?.date else { return "— —" }
        return date.formatted(in: locale, time: .shortened)
    }
    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private var nextAlarmDay: String? {
        guard let date = alarmStore.nextWake?.date else { return nil }
        return date.formatted(Date.FormatStyle(locale: locale).weekday(.wide))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ready for Shabbat.")
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        Text(Date.now.formatted(in: locale, date: .complete))
                            .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                            .padding(.top, 2)
                        Text(Date.now.hebrewDateString(in: locale))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onOpenAlarm) {
                    ZStack {
                        LivingRing(primary: WakePalette.cyan, secondary: WakePalette.blue)
                            .frame(width: 252, height: 252)
                        VStack(spacing: 7) {
                            Text(nextAlarmTime)
                                .font(.system(size: 47, weight: .light, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .accessibilityLabel(alarmStore.nextWake == nil ? Text("No alarm scheduled") : Text("Next alarm \(nextAlarmDay ?? "") \(nextAlarmTime)"))
                            Text("NEXT WAKE-UP")
                                .font(.caption2.weight(.semibold)).tracking(2.2)
                                .foregroundStyle(.secondary)
                            Group {
                                if let alarm = alarmStore.nextWake?.alarm {
                                    Text("\(alarm.title) · \(nextAlarmDay ?? "")")
                                } else {
                                    Text("No alarm scheduled")
                                }
                            }
                            .font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(width: 170)
                    }
                    .frame(height: 260)
                    .contentShape(Circle())
                    }
                    .buttonStyle(RingPressStyle())
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(Text("Opens this alarm"))

                    if alarmStore.nextWake != nil {
                        HStack(spacing: 8) {
                            Circle().fill(Color.green).frame(width: 9, height: 9)
                                .shadow(color: .green.opacity(0.8), radius: 5)
                            Text("Your alarm is ready")
                                .font(.subheadline).foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                    }

                    Button(action: onOpenTimes) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(nextShabbatTime?.category == "havdalah" ? "Shabbat ends" : "Candle lighting")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(nextShabbatTime.map { $0.date.formatted(in: locale, time: .shortened, timeZone: shabbatZone) } ?? "—")
                                    .font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 6) {
                                if let title = nextTitle, !title.isEmpty {
                                    Text(title).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                                }
                                if let item = nextShabbatTime {
                                    Text(relative(item.date))
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(WakePalette.cyan.opacity(0.3), in: Capsule())
                                        .foregroundStyle(.primary)
                                } else {
                                    Text("Choose your location to calculate times")
                                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .foregroundStyle(.primary)
                        .accessibilityElement(children: .combine)
                    }
                    .buttonStyle(.plain)

                    if !alarmStore.alarms.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Alarms")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .accessibilityAddTraits(.isHeader)
                            VStack(spacing: 0) {
                                ForEach(orderedAlarms) { alarm in
                                    alarmRow(alarm)
                                    if alarm.id != orderedAlarms.last?.id { Divider().padding(.leading, 16) }
                                }
                            }
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                    }

                    Button(action: onAddAlarm) {
                        Label("Create an alarm", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(LinearGradient(colors: [WakePalette.blue, Color(red: 0, green: 60 / 255, blue: 170 / 255)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 17))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background {
                ZStack(alignment: .top) {
                    Color(uiColor: .systemBackground)
                    RadialGradient(colors: [WakePalette.blue.opacity(0.14), .clear], center: .top, startRadius: 10, endRadius: 360)
                }.ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                let snapshot = SharedStore.load()
                nextShabbatTime = snapshot.times.first { $0.date > .now }
                shabbatZone = snapshot.timeZoneIdentifier.flatMap { TimeZone(identifier: $0) }
                nextTitle = snapshot.nextTitle
            }
        }
    }
}

private enum AppLinks {
    /// Published via GitHub Pages (Settings > Pages > main / root). The Settings screen shows a link only when one is set.
    static let privacyPolicy: URL? = URL(string: "https://davidpit1565.github.io/Shabbat-Wake/privacy/")
    static let support: URL? = URL(string: "https://davidpit1565.github.io/Shabbat-Wake/support/")
}

private struct PrivacyScreen: View {
    var body: some View {
        List {
            Section {
                Text("Your alarms, sounds and preferences are stored on this device only. Shabbat Waker has no account, no analytics and no advertising.")
            }
            Section("Feedback") {
                Text("When you send feedback, the name, email and message you type are sent to the developer. Nothing else is sent.")
            }
            Section("Credits") {
                Text("Shabbat times by [Hebcal.com](https://www.hebcal.com), licensed CC BY 4.0. Customs differ between communities, so confirm with your rabbi or local calendar.")
            }
            Section("Location") {
                Text("If you allow location access, your coordinates are used to calculate candle-lighting and havdalah times. To do that, they are sent to Hebcal.com together with your time zone. They are not sent anywhere else and are not stored by Shabbat Waker on any server.")
                Text("You can turn location access off at any time in iOS Settings. Alarms keep working without it.")
            }
        }
        .navigationTitle("Privacy")
    }
}

private struct SettingsScreen: View {
    @ObservedObject var reminders: ReminderStore
    @EnvironmentObject private var pro: ProStore
    @State private var showPaywall = false
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("preferredLanguage") private var preferredLanguage = "system"
    @AppStorage(TimeFormat.storageKey) private var timeFormat = "system"
    @State private var testMessage: String?
    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Shabbat Waker Pro") {
                    if ProStore.isEnforced && pro.hasPro {
                        Label("Pro is unlocked", systemImage: "checkmark.seal.fill").foregroundStyle(Color.green)
                    } else {
                        Button { showPaywall = true } label: { Label("See what Pro includes", systemImage: "star.circle.fill") }
                    }
                    if ProStore.isEnforced {
                        Button { Task { await pro.restore() } } label: { Label("Restore purchases", systemImage: "arrow.clockwise") }
                    }
                    if !ProStore.isEnforced {
                        Toggle("Try as a free user", isOn: Binding(get: { pro.previewFree }, set: { pro.setPreviewFree($0) }))
                        Text("While Pro is in preview everything is open. This shows the locked features so you can see how they behave.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
#if DEBUG
                    Toggle("Show the locked state (testing)", isOn: $pro.debugLocked)
#endif
                }
                Section {
                    Button {
                        Task {
                            do { try await NativeAlarmKitService.scheduleTest(); testMessage = AppLanguage.text("The test alarm will ring in about a minute. Lock your phone and put it away.") }
                            catch { testMessage = error.localizedDescription }
                        }
                    } label: { Label("Test the alarm", systemImage: "bell.badge") }
                    if let testMessage { Text(testMessage).font(.footnote).foregroundStyle(.secondary) }
                } header: { Text("Check that it rings") }
                Section("Reminders") {
                    NavigationLink {
                        RemindersScreen(store: reminders)
                    } label: {
                        Label("Before candle lighting", systemImage: "bell")
                    }
                }
                Section("Display") {
                    Picker("Time format", selection: $timeFormat) {
                        Text("System").tag("system")
                        Text("24-hour").tag("24h")
                        Text("12-hour").tag("12h")
                    }
                    Picker("Display mode", selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    NavigationLink {
                        AppIconPickerScreen()
                    } label: {
                        Label("App icon", systemImage: "app.badge")
                    }
                }
                Section("Language") {
                    Picker("App language", selection: $preferredLanguage) {
                        Text("System language").tag("system")
                        Text("English").tag("en")
                        Text("עברית").tag("he")
                        Text("Русский").tag("ru")
                        Text("Français").tag("fr")
                        Text("Español").tag("es")
                    }
                }
                Section("Sound") {
                    NavigationLink {
                        SoundLibraryScreen()
                    } label: {
                        Label("Sound library and previews", systemImage: "music.note.list")
                    }
                }
                Section("About") {
                    NavigationLink {
                        FeedbackScreen()
                    } label: {
                        Label("Send feedback", systemImage: "envelope")
                    }
                    NavigationLink("Privacy") { PrivacyScreen() }
                    if let url = AppLinks.privacyPolicy {
                        Link("Privacy policy", destination: url)
                    }
                    if let url = AppLinks.support {
                        Link("Support", destination: url)
                    }
                    LabeledContent("Version", value: versionText)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { PaywallView(reason: .general) }
        }
    }
}
