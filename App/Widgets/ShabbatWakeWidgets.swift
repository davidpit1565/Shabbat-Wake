import ActivityKit
import SwiftUI
import WidgetKit

struct ShabbatWakeWidgetEntry: TimelineEntry {
    let date: Date
}

struct ShabbatWakeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShabbatWakeWidgetEntry { .init(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (ShabbatWakeWidgetEntry) -> Void) {
        completion(.init(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShabbatWakeWidgetEntry>) -> Void) {
        let entry = ShabbatWakeWidgetEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 60))))
    }
}

struct ShabbatWakeWidgetView: View {
    var entry: ShabbatWakeWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sun.horizon.fill").foregroundStyle(.cyan)
                Text("Shabbat Wake").font(.headline)
            }
            Spacer()
            Text("Local Shabbat times").font(.subheadline.weight(.semibold))
            Text("Open the app to grant location access and load current times.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(entry.date, style: .time).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding()
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
        .description("Quick access to location-based Shabbat times.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
                Text(context.state.isLocationReady ? "Location ready" : "Location needed")
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
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isLocationReady ? "Shabbat Wake is ready" : "Location permission required")
                        .font(.caption).foregroundStyle(.secondary)
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
