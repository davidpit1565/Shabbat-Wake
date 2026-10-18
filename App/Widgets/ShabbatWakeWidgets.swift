import ActivityKit
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
            if let latitude = snapshot.latitude, let longitude = snapshot.longitude {
                let zone = snapshot.timeZoneIdentifier ?? TimeZone.current.identifier
                if var fetched = try? await ShabbatTimesService.fetch(latitude: latitude, longitude: longitude, timeZoneIdentifier: zone), !fetched.isEmpty {
                    if fetched.allSatisfy({ $0.date <= now }),
                       let next = try? await ShabbatTimesService.fetch(latitude: latitude, longitude: longitude, timeZoneIdentifier: zone, around: now.addingTimeInterval(24 * 3600)),
                       !next.isEmpty {
                        fetched = next
                    }
                    times = fetched
                    SharedStore.update { $0.times = fetched }
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
        return ShabbatWakeWidgetEntry(
            date: date,
            nextAlarm: nextAlarm(in: snapshot.alarms, after: date),
            candleLighting: upcoming.first { $0.category == "candles" },
            havdalah: upcoming.first { $0.category == "havdalah" },
            placeName: snapshot.placeName,
            hasLocation: snapshot.latitude != nil
        )
    }
}

private extension Date {
    var dayAndTime: String { formatted(.dateTime.weekday(.abbreviated).hour().minute()) }
    var timeOnly: String { formatted(date: .omitted, time: .shortened) }
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
        entry.hasLocation ? "Times unavailable" : "Open Shabbat Wake to set your location"
    }

    var body: some View {
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
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            if let alarm = entry.nextAlarm {
                Text(alarm.date.timeOnly)
                    .font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit()
                    .minimumScaleFactor(0.7)
                Text(alarm.date.formatted(.dateTime.weekday(.wide)))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No alarm set").font(.subheadline.weight(.semibold))
            }
        }
    }

    private var shabbatBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Shabbat", systemImage: "sun.horizon.fill")
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            if shabbatLines.isEmpty {
                Text(emptyShabbatMessage)
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(shabbatLines.enumerated()), id: \.offset) { _, line in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(line.label).font(.caption2).foregroundStyle(.secondary)
                        Text(line.date.dayAndTime).font(.subheadline.weight(.semibold)).monospacedDigit()
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
                    Text(line.date.dayAndTime).font(.footnote.weight(.semibold)).monospacedDigit()
                }
            } else {
                Text(emptyShabbatMessage)
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            alarmBlock
            Divider()
            shabbatBlock
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let alarm = entry.nextAlarm {
                Label(alarm.date.dayAndTime, systemImage: "alarm.fill").font(.headline)
            } else {
                Label("No alarm set", systemImage: "alarm").font(.headline)
            }
            if let candle = entry.candleLighting {
                Text("Candle lighting \(candle.date.dayAndTime)").font(.caption)
            } else if let havdalah = entry.havdalah {
                Text("Havdalah \(havdalah.date.dayAndTime)").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
    }

    @ViewBuilder private var inline: some View {
        if let alarm = entry.nextAlarm {
            Label(alarm.date.dayAndTime, systemImage: "alarm.fill")
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
                    Text(alarm.date.formatted(.dateTime.hour().minute()))
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
        .configurationDisplayName("Shabbat Wake")
        .description("Your next alarm and this week's candle-lighting and havdalah times.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct ShabbatWakeAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShabbatWakeActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "alarm.fill").font(.title2).foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.alarmTitle).font(.headline)
                    Text(context.state.scheduledAt, style: .time).font(.title3.monospacedDigit())
                }
                Spacer()
                Text("Alarm set")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.04, green: 0.09, blue: 0.18))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.fill").foregroundStyle(.cyan)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.alarmTitle).font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.scheduledAt, style: .time).monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
            } compactTrailing: {
                Text(context.state.scheduledAt, style: .time).monospacedDigit()
            } minimal: {
                Image(systemName: "alarm.fill")
            }
            .keylineTint(.cyan)
        }
    }
}

@main
struct ShabbatWakeWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShabbatWakeHomeWidget()
        ShabbatWakeAlarmLiveActivity()
    }
}
