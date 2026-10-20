import SwiftUI
import UIKit
import WidgetKit
import XCTest

/// Draws the real widget views, with their own fonts and layout, into PNG files for the App Store images.
@MainActor
final class WidgetShotTests: XCTestCase {
    private let zoneID = "Asia/Jerusalem"

    private func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zoneID)!
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func entry(_ language: String) -> ShabbatWakeWidgetEntry {
        ShabbatWakeWidgetEntry(
            date: date(22, 12, 0),
            nextAlarm: NextAlarmInfo(title: "Shabbat wake-up", date: date(26, 6, 45)),
            candleLighting: ShabbatTimeItem(id: "c", title: "Candle lighting", date: date(23, 17, 12), category: "candles"),
            havdalah: ShabbatTimeItem(id: "h", title: "Havdalah", date: date(24, 18, 14), category: "havdalah"),
            placeName: "Jerusalem",
            hasLocation: true,
            languageCode: language,
            timeFormat: language == "en" ? "12" : "24",
            timeZoneIdentifier: zoneID
        )
    }

    private func save<V: View>(_ view: V, family: WidgetFamily, size: CGSize, name: String, background: Bool) {
        let content = ZStack {
            if background { WidgetBrand.background }
            view.padding(background ? 16 : 0)
        }
        .environment(\.colorScheme, .dark)
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: background ? 24 : 0, style: .continuous))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 4
        renderer.isOpaque = false
        guard let image = renderer.uiImage else { XCTFail("no image for \(name)"); return }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = XCTAttachment.Lifetime.keepAlways
        add(attachment)
    }

    func testRenderWidgets() {
        for language in ["en", "he", "ru", "fr", "es"] {
            let e = entry(language)
            let small = CGSize(width: 170, height: 170)
            let medium = CGSize(width: 364, height: 170)
            let rect = CGSize(width: 170, height: 76)
            save(SingleTimeWidgetView(entry: e, kind: .candles, familyOverride: .systemSmall), family: .systemSmall, size: small, name: "w-\(language)-small-candle", background: true)
            save(SingleTimeWidgetView(entry: e, kind: .ends, familyOverride: .systemSmall), family: .systemSmall, size: small, name: "w-\(language)-small-ends", background: true)
            save(ShabbatWakeWidgetView(entry: e, familyOverride: .systemSmall), family: .systemSmall, size: small, name: "w-\(language)-small-home", background: true)
            save(ShabbatWakeWidgetView(entry: e, familyOverride: .systemMedium), family: .systemMedium, size: medium, name: "w-\(language)-medium-home", background: true)
            save(SingleTimeWidgetView(entry: e, kind: .ends, familyOverride: .systemMedium), family: .systemMedium, size: medium, name: "w-\(language)-medium-ends", background: true)
            save(SingleTimeWidgetView(entry: e, kind: .ends, familyOverride: .accessoryRectangular), family: .accessoryRectangular, size: rect, name: "w-\(language)-lock-ends", background: false)
        }
    }
}
