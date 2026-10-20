import SwiftUI
import WatchConnectivity
import WidgetKit

@main
struct ShabbatWakeWatchApp: App {
    @StateObject private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchHome(model: model)
        }
    }
}

/// Receives the times and alarms from the iPhone and keeps them where the complications can read them.
@MainActor
final class WatchModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot = SharedStore.load()

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        Task { @MainActor in self.apply(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    private func apply(_ context: [String: Any]) {
        guard let data = context["snapshot"] as? Data, let received = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return }
        SharedStore.replace(received)
        snapshot = received
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct WatchHome: View {
    @ObservedObject var model: WatchModel

    private var locale: Locale { model.snapshot.languageCode.map { TimeFormat.locale(language: $0, format: model.snapshot.timeFormat) } ?? .current }
    private var upcoming: [ShabbatTimeItem] { model.snapshot.times.filter { $0.date > .now } }
    private var candle: Date? { upcoming.first { $0.category == "candles" }?.date }
    private var havdalah: Date? { upcoming.first { $0.category == "havdalah" }?.date }
    /// Candle lighting and havdalah are in the place's time zone, like on the iPhone; alarms stay on the watch's own clock.
    private var placeZone: TimeZone? { model.snapshot.timeZoneIdentifier.flatMap { TimeZone(identifier: $0) } }
    private var alarm: Date? { model.snapshot.alarms.compactMap { $0.nextFireDate() }.min() }

    var body: some View {
        TabView {
            page(title: "Candle lighting", symbol: "candles", tint: Color(red: 1, green: 0.72, blue: 0.42), date: candle, zone: placeZone)
            page(title: "Shabbat ends", symbol: "moon.stars.fill", tint: Color(red: 0.35, green: 0.9, blue: 1), date: havdalah, zone: placeZone)
            page(title: "Next alarm", symbol: "alarm.fill", tint: Color(red: 0.4, green: 0.6, blue: 1), date: alarm, emptyText: "No alarm set")
        }
        .tabViewStyle(.verticalPage)
        .environment(\.locale, locale)
        .environment(\.layoutDirection, model.snapshot.languageCode == "he" ? .rightToLeft : .leftToRight)
        .containerBackground(
            LinearGradient(colors: [Color(red: 0.04, green: 0.07, blue: 0.16), Color(red: 0.07, green: 0.19, blue: 0.43)], startPoint: .top, endPoint: .bottom),
            for: .tabView
        )
    }

    private func page(title: LocalizedStringKey, symbol: String, tint: Color, date: Date?, zone: TimeZone? = nil, emptyText: LocalizedStringKey = "Open Shabbat Waker on your iPhone to load times.") -> some View {
        VStack(spacing: 6) {
            Label { Text(title) } icon: { KindIcon(symbol: symbol) }
                .font(.footnote.weight(.semibold)).foregroundStyle(tint)
            if let date {
                Text(date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: zone ?? .current)))
                    .font(.system(size: 40, weight: .semibold, design: .rounded)).monospacedDigit()
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(date.formatted(Date.FormatStyle(locale: locale, timeZone: zone ?? .current).weekday(.wide).day().month(.abbreviated)))
                    .font(.footnote).foregroundStyle(.secondary)
                Text(date, style: .relative)
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(emptyText).font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            if let place = model.snapshot.placeName {
                Text(place).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
    }
}
