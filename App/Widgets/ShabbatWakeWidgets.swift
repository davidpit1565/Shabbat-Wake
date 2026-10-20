import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

struct NextAlarmInfo: Equatable {
    let title: String
    let date: Date
}

struct ShabbatWakeWidgetEntry: TimelineEntry {
    let date: Date
    let nextAlarm: NextAlarmInfo?
    let candleLighting: ShabbatTimeItem?
    let havdalah: ShabbatTimeItem?
    let placeName: String?
    let hasLocation: Bool
    var relevance: TimelineEntryRelevance? = nil
    var hasPro: Bool = true
    var languageCode: String? = nil
    var timeFormat: String? = nil
    var timeZoneIdentifier: String? = nil

    /// Candle lighting and Shabbat ends belong to the place, not to the phone's time zone.
    var placeZone: TimeZone? { timeZoneIdentifier.flatMap { TimeZone(identifier: $0) } }
    var locale: Locale { languageCode.map { TimeFormat.locale(language: $0, format: timeFormat) } ?? .current }
    var isRightToLeft: Bool { languageCode == "he" }

    static let placeholder = ShabbatWakeWidgetEntry(
        date: .now,
        nextAlarm: NextAlarmInfo(title: "Shabbat wake-up", date: .now.addingTimeInterval(8 * 3600)),
        candleLighting: nil,
        havdalah: nil,
        placeName: nil,
        hasLocation: false
    )
}

struct ShabbatWakeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShabbatWakeWidgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (ShabbatWakeWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        let snapshot = SharedStore.load()
        completion(Self.entry(at: .now, snapshot: snapshot, times: snapshot.times))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShabbatWakeWidgetEntry>) -> Void) {
        Task {
            let snapshot = SharedStore.load()
            let now = Date()
            var times = snapshot.times
            // The app keeps about half a year of times (Shabbat and Yom Tov) in the shared store. Only when none is left
            // does the widget ask Hebcal itself, and it never overwrites the stored list with that short answer.
            if !times.contains(where: { $0.date > now }), let latitude = snapshot.latitude, let longitude = snapshot.longitude {
                let zone = snapshot.timeZoneIdentifier ?? TimeZone.current.identifier
                if let fetched = try? await ShabbatTimesService.fetch(latitude: latitude, longitude: longitude, timeZoneIdentifier: zone), !fetched.isEmpty {
                    times = fetched
                }
            }

            var boundaries: Set<Date> = [now]
            for item in times where item.date > now { boundaries.insert(item.date) }
            var cursor = now
            for _ in 0..<4 {
                guard let next = Self.nextAlarm(in: snapshot.alarms, after: cursor) else { break }
                boundaries.insert(next.date)
                cursor = next.date
            }
            let entries = boundaries.sorted().prefix(12).map { Self.entry(at: $0, snapshot: snapshot, times: times) }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(4 * 3600))))
        }
    }

    static func nextAlarm(in alarms: [WakeAlarm], after date: Date) -> NextAlarmInfo? {
        alarms.compactMap { alarm in
            alarm.nextFireDate(after: date).map { NextAlarmInfo(title: alarm.title, date: $0) }
        }.min { $0.date < $1.date }
    }

    static func entry(at date: Date, snapshot: WidgetSnapshot, times: [ShabbatTimeItem]) -> ShabbatWakeWidgetEntry {
        let upcoming = times.filter { $0.date > date }
        var entry = ShabbatWakeWidgetEntry(
            date: date,
            nextAlarm: nextAlarm(in: snapshot.alarms, after: date),
            candleLighting: upcoming.first { $0.category == "candles" },
            havdalah: upcoming.first { $0.category == "havdalah" },
            placeName: snapshot.placeName,
            hasLocation: snapshot.latitude != nil,
            hasPro: snapshot.proUnlocked ?? true,
            languageCode: snapshot.languageCode,
            timeFormat: snapshot.timeFormat,
            timeZoneIdentifier: snapshot.timeZoneIdentifier
        )
        // Smart Stack: raise the widget in the hours before candle lighting.
        if let candle = entry.candleLighting?.date, candle.timeIntervalSince(date) <= 4 * 3600 {
            entry.relevance = TimelineEntryRelevance(score: 100, duration: max(60, candle.timeIntervalSince(date) + 1800))
        }
        return entry
    }
}

private extension Date {
    private func style(_ base: Date.FormatStyle, _ zone: TimeZone?) -> Date.FormatStyle {
        var style = base
        if let zone { style.timeZone = zone }
        return style
    }
    func dayAndTime(_ locale: Locale, in zone: TimeZone? = nil) -> String { formatted(style(Date.FormatStyle(locale: locale).weekday(.abbreviated).hour().minute(), zone)) }
    func timeOnly(_ locale: Locale, in zone: TimeZone? = nil) -> String { formatted(style(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale), zone)) }
    func weekdayName(_ locale: Locale, in zone: TimeZone? = nil) -> String { formatted(style(Date.FormatStyle(locale: locale).weekday(.wide), zone)) }
    func hourMinute(_ locale: Locale, in zone: TimeZone? = nil) -> String { formatted(style(Date.FormatStyle(locale: locale).hour().minute(), zone)) }
}

/// The app's look on the Home Screen: deep blue with a cyan glow, whatever the system appearance.
enum WidgetBrand {
    static let cyan = Color(red: 89 / 255, green: 230 / 255, blue: 1)
    static let blue = Color(red: 40 / 255, green: 116 / 255, blue: 1)

    static var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.07, blue: 0.16), Color(red: 0.07, green: 0.19, blue: 0.43)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [cyan.opacity(0.30), .clear], center: .topTrailing, startRadius: 4, endRadius: 170)
        }
    }
}

struct ShabbatWakeWidgetView: View {
    var entry: ShabbatWakeWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var shabbatLines: [(label: LocalizedStringKey, date: Date)] {
        var lines: [(label: LocalizedStringKey, date: Date)] = []
        if let candle = entry.candleLighting { lines.append((label: "Candle lighting", date: candle.date)) }
        if let havdalah = entry.havdalah { lines.append((label: "Havdalah", date: havdalah.date)) }
        return lines
    }

    private var emptyShabbatMessage: LocalizedStringKey {
        entry.hasLocation ? "Times unavailable" : "Open Shabbat Waker to set your location"
    }

    var body: some View {
        content
        .environment(\.locale, entry.locale)
        .environment(\.layoutDirection, entry.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    private var alarmBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Next alarm", systemImage: "alarm.fill")
                .font(.caption2.weight(.semibold)).foregroundStyle(WidgetBrand.cyan)
            if let alarm = entry.nextAlarm {
                Text(alarm.date.timeOnly(entry.locale))
                    .font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit()
                    .minimumScaleFactor(0.7)
                Text(alarm.date.weekdayName(entry.locale))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No alarm set").font(.subheadline.weight(.semibold))
            }
        }
    }

    private var shabbatBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Shabbat", systemImage: "sun.horizon.fill")
                .font(.caption2.weight(.semibold)).foregroundStyle(WidgetBrand.cyan)
            if shabbatLines.isEmpty {
                Text(emptyShabbatMessage)
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(shabbatLines.enumerated()), id: \.offset) { _, line in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(line.label).font(.caption2).foregroundStyle(.secondary)
                        Text(line.date.dayAndTime(entry.locale, in: entry.placeZone)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                }
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            alarmBlock
            Spacer(minLength: 0)
            if let line = shabbatLines.first {
                VStack(alignment: .leading, spacing: 0) {
                    Text(line.label).font(.caption2).foregroundStyle(.secondary)
                    Text(line.date.dayAndTime(entry.locale, in: entry.placeZone)).font(.footnote.weight(.semibold)).monospacedDigit()
                }
            } else {
                Text(emptyShabbatMessage)
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { WidgetBrand.background }
        .environment(\.colorScheme, .dark)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            alarmBlock
            Divider()
            shabbatBlock
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { WidgetBrand.background }
        .environment(\.colorScheme, .dark)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let alarm = entry.nextAlarm {
                Label(alarm.date.dayAndTime(entry.locale), systemImage: "alarm.fill").font(.headline)
            } else {
                Label("No alarm set", systemImage: "alarm").font(.headline)
            }
            if let candle = entry.candleLighting {
                Text("Candle lighting \(candle.date.dayAndTime(entry.locale, in: entry.placeZone))").font(.caption)
            } else if let havdalah = entry.havdalah {
                Text("Havdalah \(havdalah.date.dayAndTime(entry.locale, in: entry.placeZone))").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
    }

    @ViewBuilder private var inline: some View {
        if let alarm = entry.nextAlarm {
            Label(alarm.date.dayAndTime(entry.locale), systemImage: "alarm.fill")
        } else {
            Label("No alarm set", systemImage: "alarm")
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "alarm.fill").font(.caption2)
                if let alarm = entry.nextAlarm {
                    Text(alarm.date.hourMinute(entry.locale))
                        .font(.caption.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.6)
                } else {
                    Text("—").font(.caption)
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

struct ShabbatWakeHomeWidget: Widget {
    let kind = "ShabbatWakeHomeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShabbatWakeWidgetProvider()) { entry in
            ShabbatWakeWidgetView(entry: entry)
        }
        .configurationDisplayName("Shabbat Waker")
        .description("Your next alarm and this week's candle-lighting and havdalah times.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}


// MARK: - Single-time widgets (candle lighting, Shabbat ends)

enum SingleTimeKind {
    case candles, ends

    var title: LocalizedStringKey { self == .candles ? "Candle lighting" : "Shabbat ends" }
    var symbol: String { self == .candles ? "candles" : "moon.stars.fill" }
    var tint: Color { self == .candles ? Color(red: 1, green: 0.72, blue: 0.42) : WidgetBrand.cyan }
    func item(_ entry: ShabbatWakeWidgetEntry) -> ShabbatTimeItem? { self == .candles ? entry.candleLighting : entry.havdalah }
}

struct SingleTimeWidgetView: View {
    let entry: ShabbatWakeWidgetEntry
    let kind: SingleTimeKind
    @Environment(\.widgetFamily) private var family

    private var date: Date? { kind.item(entry)?.date }

    var body: some View {
        content
        .environment(\.locale, entry.locale)
        .environment(\.layoutDirection, entry.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline:
            Label { Text(date.map { $0.dayAndTime(entry.locale, in: entry.placeZone) } ?? "—") } icon: { KindIcon(symbol: kind.symbol) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(kind.title) + Text(" ") + Text(date.map { $0.dayAndTime(entry.locale, in: entry.placeZone) } ?? "—"))
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    KindIcon(symbol: kind.symbol, size: 13)
                    Text(date?.hourMinute(entry.locale, in: entry.placeZone) ?? "—")
                        .font(.caption.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(kind.title) + Text(" ") + Text(date?.hourMinute(entry.locale, in: entry.placeZone) ?? "—"))
            .containerBackground(.background, for: .widget)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label { Text(kind.title) } icon: { KindIcon(symbol: kind.symbol) }.font(.caption.weight(.semibold))
                Text(date?.timeOnly(entry.locale, in: entry.placeZone) ?? "—").font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                if let date { Text(date.weekdayName(entry.locale, in: entry.placeZone)).font(.caption2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(.background, for: .widget)
        default:
            let medium = family == .systemMedium
            VStack(alignment: .leading, spacing: medium ? 6 : 4) {
                Spacer(minLength: 0)
                Label { Text(kind.title) } icon: { KindIcon(symbol: kind.symbol, size: medium ? 22 : 18) }
                    .font(.system(size: medium ? 18 : 14, weight: .semibold))
                    .foregroundStyle(WidgetBrand.cyan)
                Text(date?.timeOnly(entry.locale, in: entry.placeZone) ?? "--:--")
                    .font(.system(size: medium ? 64 : 42, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.5)
                if let date {
                    Text(date.weekdayName(entry.locale, in: entry.placeZone))
                        .font(.system(size: medium ? 24 : 18, weight: .bold, design: .rounded))
                        .foregroundStyle(kind.tint)
                        .lineLimit(1).minimumScaleFactor(0.6)
                } else {
                    Text(entry.hasLocation ? "Times unavailable" : "Open Shabbat Waker to set your location")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { WidgetBrand.background }
            .environment(\.colorScheme, .dark)
        }
    }
}

struct CandleLightingWidget: Widget {
    let kind = "ShabbatWakeCandleWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShabbatWakeWidgetProvider()) { entry in
            SingleTimeWidgetView(entry: entry, kind: .candles)
        }
        .configurationDisplayName("Candle lighting")
        .description("The next candle-lighting time for your location.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct ShabbatEndsWidget: Widget {
    let kind = "ShabbatWakeEndsWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShabbatWakeWidgetProvider()) { entry in
            SingleTimeWidgetView(entry: entry, kind: .ends)
        }
        .configurationDisplayName("Shabbat ends")
        .description("When Shabbat ends at your location.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

/// How a system alarm looks on the Lock Screen and in the Dynamic Island. AlarmKit needs the widget extension to
/// provide it; without it alarms cannot present themselves, and so cannot ring.
@available(iOS 26.1, *)
struct ShabbatWakeAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<ShabbatWakeAlarmMetadata>.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "alarm.fill").font(.title2).foregroundStyle(context.attributes.tintColor)
                Text(context.attributes.metadata?.title ?? "")
                    .font(.headline)
                Spacer()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.fill").foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.metadata?.title ?? "").font(.headline)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill").foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: "alarm.fill").foregroundStyle(context.attributes.tintColor)
            }
        }
    }
}

#if !WIDGET_SHOTS
@main
#endif
struct ShabbatWakeWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShabbatWakeHomeWidget()
        CandleLightingWidget()
        ShabbatEndsWidget()
        if #available(iOS 26.1, *) {
            ShabbatWakeAlarmLiveActivity()
        }
    }
}
