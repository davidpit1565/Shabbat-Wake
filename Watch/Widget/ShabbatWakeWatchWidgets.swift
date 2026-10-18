import SwiftUI
import WidgetKit

struct WatchEntry: TimelineEntry {
    let date: Date
    let candle: Date?
    let havdalah: Date?
    let alarm: Date?
    let languageCode: String?

    var locale: Locale { languageCode.map { Locale(identifier: $0) } ?? .current }
}

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: .now, candle: .now.addingTimeInterval(3600 * 20), havdalah: .now.addingTimeInterval(3600 * 48), alarm: .now.addingTimeInterval(3600 * 8), languageCode: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(Self.entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let snapshot = SharedStore.load()
        var dates: Set<Date> = [.now]
        for item in snapshot.times where item.date > .now { dates.insert(item.date) }
        for alarm in snapshot.alarms { if let fire = alarm.nextFireDate() { dates.insert(fire) } }
        let entries = dates.sorted().prefix(12).map { Self.entry(at: $0) }
        completion(Timeline(entries: entries, policy: .after(.now.addingTimeInterval(6 * 3600))))
    }

    static func entry(at date: Date) -> WatchEntry {
        let snapshot = SharedStore.load()
        let upcoming = snapshot.times.filter { $0.date > date }
        return WatchEntry(
            date: date,
            candle: upcoming.first { $0.category == "candles" }?.date,
            havdalah: upcoming.first { $0.category == "havdalah" }?.date,
            alarm: snapshot.alarms.compactMap { $0.nextFireDate(after: date) }.min(),
            languageCode: snapshot.languageCode
        )
    }
}

enum WatchKind {
    case candle, ends, alarm

    var symbol: String {
        switch self {
        case .candle: return "flame.fill"
        case .ends: return "moon.stars.fill"
        case .alarm: return "alarm.fill"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .candle: return "Candle lighting"
        case .ends: return "Shabbat ends"
        case .alarm: return "Next alarm"
        }
    }

    func value(_ entry: WatchEntry) -> Date? {
        switch self {
        case .candle: return entry.candle
        case .ends: return entry.havdalah
        case .alarm: return entry.alarm
        }
    }
}

struct WatchComplicationView: View {
    let entry: WatchEntry
    let kind: WatchKind
    @Environment(\.widgetFamily) private var family

    private var time: String {
        guard let date = kind.value(entry) else { return "—" }
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: entry.locale))
    }

    private var day: String {
        guard let date = kind.value(entry) else { return "" }
        return date.formatted(Date.FormatStyle(locale: entry.locale).weekday(.abbreviated))
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label("\(day) \(time)", systemImage: kind.symbol)
            case .accessoryCircular, .accessoryCorner:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Image(systemName: kind.symbol).font(.caption2)
                        Text(time).font(.caption2.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 1) {
                    Label(kind.title, systemImage: kind.symbol).font(.caption.weight(.semibold))
                    Text(time).font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                    if !day.isEmpty { Text(day).font(.caption2) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .environment(\.locale, entry.locale)
        .environment(\.layoutDirection, entry.languageCode == "he" ? .rightToLeft : .leftToRight)
        .containerBackground(.background, for: .widget)
    }
}

struct WatchCandleComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchCandle", provider: WatchProvider()) { entry in
            WatchComplicationView(entry: entry, kind: .candle)
        }
        .configurationDisplayName("Candle lighting")
        .description("The next candle-lighting time.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct WatchEndsComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchEnds", provider: WatchProvider()) { entry in
            WatchComplicationView(entry: entry, kind: .ends)
        }
        .configurationDisplayName("Shabbat ends")
        .description("When Shabbat ends.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct WatchAlarmComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchAlarm", provider: WatchProvider()) { entry in
            WatchComplicationView(entry: entry, kind: .alarm)
        }
        .configurationDisplayName("Next alarm")
        .description("Your next alarm.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

@main
struct ShabbatWakeWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchCandleComplication()
        WatchEndsComplication()
        WatchAlarmComplication()
    }
}
