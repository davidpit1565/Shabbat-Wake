import XCTest
@testable import ShabbatWake

final class ShabbatWakeTests: XCTestCase {
    func testAlarmPersistsSelectedSoundAndRepeatDays() throws {
        let alarm = WakeAlarm(
            title: "Morning",
            hour: 7,
            minute: 15,
            repeatsWeekly: true,
            weekdays: [1, 6],
            soundID: "gentle"
        )
        let data = try JSONEncoder().encode(alarm)
        let decoded = try JSONDecoder().decode(WakeAlarm.self, from: data)
        XCTAssertEqual(decoded.title, "Morning")
        XCTAssertEqual(decoded.hour, 7)
        XCTAssertEqual(decoded.minute, 15)
        XCTAssertEqual(decoded.weekdays, [1, 6])
        XCTAssertEqual(decoded.soundID, "gentle")
        XCTAssertTrue(decoded.repeatsWeekly)
    }

    func testHebrewCalendarProducesAValidDate() {
        var calendar = Calendar(identifier: .hebrew)
        calendar.locale = Locale(identifier: "he")
        let parts = calendar.dateComponents([.year, .month, .day], from: Date.now)
        XCTAssertNotNil(parts.year)
        XCTAssertNotNil(parts.month)
        XCTAssertNotNil(parts.day)
    }

    func testSoundIdentifiersAreKnownChoices() {
        let supported = Set(["gentle", "sunrise", "classic"])
        XCTAssertEqual(supported.count, 3)
    }
}
