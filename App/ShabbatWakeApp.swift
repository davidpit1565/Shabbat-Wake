import SwiftUI

@main
struct ShabbatWakeApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    init() {
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

private enum WakePalette {
    static let blue = Color(red: 40 / 255, green: 116 / 255, blue: 1)
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
    @Environment(\.scenePhase) private var scenePhase

    private var languageCode: String { AppLanguage.effectiveCode(for: preferredLanguage) }

    var body: some View {
        // Set before the views below are created, so navigation and tab bars pick up the right direction.
        let _ = AppLanguage.applyDirection(for: languageCode)
        TabView(selection: $selectedTab) {
            HomeDashboard(alarmStore: alarmStore, onAddAlarm: { showAddAlarm = true }, onOpenTimes: { selectedTab = .times })
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
        .sheet(isPresented: $permissions.isPresented) { PermissionsSheet(gate: permissions) }
        .sheet(item: $browserLink) { InAppBrowser(url: $0.url).ignoresSafeArea() }
        // Applied after the sheets so the sheets receive them too. A sheet only inherits what is set outside it.
        .environmentObject(pro)
        .environment(\.locale, Locale(identifier: languageCode))
        .environment(\.layoutDirection, AppLanguage.isRightToLeft(languageCode) ? .rightToLeft : .leftToRight)
        .environment(\.openURL, OpenURLAction { url in
            // Web links open inside the app; anything else (mail, settings) goes to the system.
            guard url.scheme == "https" || url.scheme == "http" else { return .systemAction }
            browserLink = InAppLink(url: url)
            return .handled
        })
        .task {
            await permissions.checkOnLaunch()
            await alarmStore.refreshFromSystem()
            WidgetSync.updateLanguage(languageCode)
            await pro.start()
            await TimesRefresher.refreshIfNeeded()
            await reminders.reschedule()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shabbatTimesUpdated)) { _ in
            Task { await reminders.reschedule() }
        }
        .onChange(of: languageCode) { _, code in
            WidgetSync.updateLanguage(code)
            Task { await reminders.reschedule() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                permissions.refresh()
                Task { await alarmStore.refreshFromSystem() }
            }
        }
    }
}

struct HomeDashboard: View {
    @ObservedObject var alarmStore: AlarmStore
    var onAddAlarm: () -> Void
    var onOpenTimes: () -> Void
    @Environment(\.locale) private var locale

    @State private var nextShabbatTime: ShabbatTimeItem?

    private var nextAlarmTime: String {
        guard let date = alarmStore.nextWake?.date else { return "— —" }
        return date.formatted(in: locale, time: .shortened)
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
                    .accessibilityElement(children: .combine)

                    Button(action: onOpenTimes) {
                        HStack(spacing: 13) {
                            Image(systemName: "sun.horizon.fill")
                                .font(.title2).foregroundStyle(WakePalette.cyan)
                                .frame(width: 46, height: 46)
                                .background(WakePalette.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Shabbat times").font(.subheadline.weight(.semibold))
                                if let item = nextShabbatTime {
                                    Text("\(item.category == "candles" ? AppLanguage.text("Candle lighting") : AppLanguage.text("Shabbat ends")) · \(item.date.formatted(Date.FormatStyle(locale: locale).weekday(.abbreviated).hour().minute()))")
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text("Choose your location to calculate times")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: locale.identifier.hasPrefix("he") ? "chevron.left" : "chevron.right")
                                .font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                        }
                        .padding(15)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    Button(action: onAddAlarm) {
                        Label("Create an alarm", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(LinearGradient(colors: [WakePalette.cyan, WakePalette.blue], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 17))
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
            .onAppear { nextShabbatTime = SharedStore.load().times.first { $0.date > .now } }
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
#if DEBUG
                    Toggle("Show the locked state (testing)", isOn: $pro.debugLocked)
#endif
                }
                Section("Reminders") {
                    NavigationLink {
                        RemindersScreen(store: reminders)
                    } label: {
                        Label("Before candle lighting", systemImage: "bell")
                    }
                }
                Section("Display") {
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
