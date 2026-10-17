import SwiftUI

@main
struct ShabbatWakeApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = "system"

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
    static let navy = Color(red: 7 / 255, green: 16 / 255, blue: 32 / 255)
    static let panel = Color(red: 16 / 255, green: 36 / 255, blue: 64 / 255)
    static let blue = Color(red: 40 / 255, green: 116 / 255, blue: 1)
    static let cyan = Color(red: 89 / 255, green: 230 / 255, blue: 1)
    static let silver = Color(red: 201 / 255, green: 216 / 255, blue: 236 / 255)
}

private enum MainTab: String, CaseIterable, Identifiable {
    case home, alarms, calendar, readiness, settings
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .alarms: "Alarms"
        case .calendar: "Calendar"
        case .readiness: "Readiness"
        case .settings: "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .home: "circle.dashed.inset.filled"
        case .alarms: "alarm"
        case .calendar: "calendar"
        case .readiness: "checkmark.shield"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct RootView: View {
    @State private var selectedTab: MainTab = .home
    @State private var showAddAlarm = false
    @StateObject private var alarmStore = AlarmStore()
    @AppStorage("preferredLanguage") private var preferredLanguage = "system"

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeDashboard(onAddAlarm: { showAddAlarm = true })
                .tabItem { Label(MainTab.home.title, systemImage: MainTab.home.symbol) }
                .tag(MainTab.home)
            AlarmListScreen(store: alarmStore, onAddAlarm: { showAddAlarm = true })
                .tabItem { Label(MainTab.alarms.title, systemImage: MainTab.alarms.symbol) }
                .tag(MainTab.alarms)
            ShabbatTimesScreen()
                .tabItem { Label(MainTab.calendar.title, systemImage: MainTab.calendar.symbol) }
                .tag(MainTab.calendar)
            ReadinessScreen(store: alarmStore)
                .tabItem { Label(MainTab.readiness.title, systemImage: MainTab.readiness.symbol) }
                .tag(MainTab.readiness)
            SettingsScreen()
                .tabItem { Label(MainTab.settings.title, systemImage: MainTab.settings.symbol) }
                .tag(MainTab.settings)
        }
        .tint(WakePalette.blue)
        .environment(\.locale, Locale(identifier: preferredLanguage == "system" ? Locale.current.identifier : preferredLanguage))
        .environment(\.layoutDirection, preferredLanguage == "he" ? .rightToLeft : .leftToRight)
        .sheet(isPresented: $showAddAlarm) { AddAlarmSheet(store: alarmStore) }
    }
}

struct HomeDashboard: View {
    var onAddAlarm: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateHalo = false
    private let sampleTime = "07:00"

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            Text("Shabbat, in sync.")
                                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        }
                        Spacer()
                        Image(systemName: "sparkle")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(WakePalette.cyan)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    VStack(spacing: 18) {
                        ZStack {
                            Circle().fill(WakePalette.blue.opacity(animateHalo ? 0.15 : 0.07))
                                .frame(width: 260, height: 260).blur(radius: 28)
                            Circle().stroke(WakePalette.silver.opacity(0.16), lineWidth: 1)
                                .frame(width: 230, height: 230)
                            Circle().trim(from: 0.06, to: 0.78)
                                .stroke(AngularGradient(colors: [WakePalette.cyan, WakePalette.blue, WakePalette.silver.opacity(0.25)], center: .center), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .frame(width: 230, height: 230)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: WakePalette.blue.opacity(0.55), radius: 12)
                            Circle().stroke(WakePalette.cyan.opacity(0.12), lineWidth: 1)
                                .frame(width: 208, height: 208)
                            VStack(spacing: 7) {
                                Text(sampleTime)
                                    .font(.system(size: 47, weight: .light, design: .rounded))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    .accessibilityLabel("Example next alarm time, 7 AM")
                                Text("NEXT WAKE-UP")
                                    .font(.caption2.weight(.semibold)).tracking(2.2)
                                    .foregroundStyle(.secondary)
                                Text("Sample schedule · not yet set")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .rotationEffect(.degrees(0)) // Time and text stay stationary; only the perimeter may move.
                            Circle().fill(.white).frame(width: 6, height: 6)
                                .shadow(color: WakePalette.cyan, radius: 8)
                                .offset(y: -116)
                                .rotationEffect(.degrees(animateHalo ? 28 : 0))
                        }
                        .frame(height: 270)
                        .onAppear {
                            guard !reduceMotion else { return }
                            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) { animateHalo = true }
                        }
                        .accessibilityElement(children: .combine)

                        HStack(spacing: 13) {
                            Image(systemName: "sun.horizon.fill")
                                .font(.title2).foregroundStyle(WakePalette.cyan)
                                .frame(width: 46, height: 46)
                                .background(WakePalette.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Shabbat timing").font(.subheadline.weight(.semibold))
                                Text("Choose your location to calculate times")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                        }
                        .padding(15)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                        HStack(spacing: 12) {
                            StatusTile(title: "ALARMS", value: "Not set", symbol: "alarm")
                            StatusTile(title: "READINESS", value: "Not checked", symbol: "checkmark.shield")
                        }

                        Button(action: onAddAlarm) {
                            Label("Create an alarm", systemImage: "plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(LinearGradient(colors: [WakePalette.cyan, WakePalette.blue], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 17))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
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
        }
    }
}

private struct StatusTile: View {
    let title: LocalizedStringKey
    let value: LocalizedStringKey
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(WakePalette.cyan)
            Text(title).font(.caption2.weight(.semibold)).tracking(1.2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct PlaceholderScreen: View {
    let title: LocalizedStringKey
    let symbol: String
    let detail: LocalizedStringKey
    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
                .navigationTitle(title)
        }
    }
}

private struct AddAlarmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AlarmStore
    @State private var title = "Shabbat wake-up"
    @State private var time = Date.now
    @State private var repeatWeekly = true
    var body: some View {
        NavigationStack {
            Form {
                Section("Alarm details") {
                    TextField("Alarm name", text: $title)
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    Toggle("Repeat weekly", isOn: $repeatWeekly)
                }
                Section {
                    Label("Saved on this device", systemImage: "internaldrive")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Saving requests an Apple system alarm. The alarm will be saved only if iOS grants permission and scheduling succeeds.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let saved = await store.add(title: title, time: time, repeatsWeekly: repeatWeekly, weekdays: repeatWeekly ? Set(1...7) : [])
                            if saved { dismiss() }
                        }
                    }
                }
            }
        }
    }
}

private struct SettingsScreen: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("preferredLanguage") private var preferredLanguage = "system"
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }
                Section("Language") {
                    Picker("App language", selection: $preferredLanguage) {
                        Text("System language").tag("system")
                        Text("English").tag("en")
                        Text("עברית").tag("he")
                    }
                    Text("Choose English or Hebrew. Some system-provided labels may follow the iPhone language.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Sound") {
                    NavigationLink {
                        SoundLibraryScreen()
                    } label: {
                        Label("Sound library and previews", systemImage: "music.note.list")
                    }
                    Text("Choose a sound for preview; the selected tone is used by supported system alarms.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
