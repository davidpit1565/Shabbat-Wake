import XCTest
@testable import ShabbatWake

final class ShabbatWakeTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    // 2026-10-18 is a Sunday; 2026-10-24 is a Saturday.

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
        XCTAssertNil(decoded.armedAt)
    }

    func testWeeklySaturdayAlarmFiresNextSaturday() {
        let alarm = WakeAlarm(title: "Shabbat", hour: 7, minute: 0, repeatsWeekly: true, weekdays: [7])
        XCTAssertEqual(alarm.nextFireDate(after: date(18, 12), calendar: calendar), date(24, 7))
    }

    func testWeeklyAlarmLaterTodayFiresToday() {
        let alarm = WakeAlarm(title: "Shabbat", hour: 7, minute: 0, repeatsWeekly: true, weekdays: [7])
        XCTAssertEqual(alarm.nextFireDate(after: date(24, 6), calendar: calendar), date(24, 7))
    }

    func testWeeklyAlarmExactlyNowFiresNextWeek() {
        let alarm = WakeAlarm(title: "Shabbat", hour: 7, minute: 0, repeatsWeekly: true, weekdays: [7])
        XCTAssertEqual(alarm.nextFireDate(after: date(24, 7), calendar: calendar), date(31, 7))
    }

    func testWeeklyAlarmPicksEarliestSelectedDay() {
        let alarm = WakeAlarm(title: "Multi", hour: 7, minute: 30, repeatsWeekly: true, weekdays: [1, 6, 7])
        // From Sunday noon: Sunday 07:30 has passed, Friday (day 6) is the next one.
        XCTAssertEqual(alarm.nextFireDate(after: date(18, 12), calendar: calendar), date(23, 7, 30))
    }

    func testDisabledAlarmHasNoNextFireDate() {
        var alarm = WakeAlarm(title: "Off", hour: 7, minute: 0, repeatsWeekly: true, weekdays: [7])
        alarm.isEnabled = false
        XCTAssertNil(alarm.nextFireDate(after: date(18, 12), calendar: calendar))
    }

    func testOneTimeAlarmFiresOnceThenExpires() {
        var alarm = WakeAlarm(title: "Once", hour: 7, minute: 0, repeatsWeekly: false, weekdays: [])
        alarm.armedAt = date(18, 12)
        XCTAssertEqual(alarm.nextFireDate(after: date(18, 13), calendar: calendar), date(19, 7))
        XCTAssertNil(alarm.nextFireDate(after: date(19, 8), calendar: calendar))
    }

    func testRepeatSummaryUsesSelectedDays() {
        let alarm = WakeAlarm(title: "Shabbat", hour: 7, minute: 0, repeatsWeekly: true, weekdays: [7, 1])
        let summary = alarm.repeatSummary(locale: Locale(identifier: "en_US"))
        XCTAssertEqual(summary, "Sun, Sat")
    }

    func testHebcalResponseKeepsOnlyCandlesAndHavdalah() throws {
        let json = """
        {"items":[
          {"title":"Candle lighting: 5:56pm","date":"2026-10-16T17:56:00-04:00","category":"candles"},
          {"title":"Parashat Noach","date":"2026-10-17","category":"parashat"},
          {"title":"Havdalah: 6:53pm","date":"2026-10-17T18:53:00-04:00","category":"havdalah"}
        ]}
        """
        let items = try ShabbatTimesService.parse(Data(json.utf8))
        XCTAssertEqual(items.map(\.category), ["candles", "havdalah"])
        let candle = ISO8601DateFormatter().date(from: "2026-10-16T21:56:00Z")
        XCTAssertEqual(items.first?.date, candle)
    }

    func testHebcalURLCarriesLocationTimeZoneAndDate() throws {
        let url = try XCTUnwrap(ShabbatTimesService.makeURL(latitude: 32.0853, longitude: 34.7818, timeZoneIdentifier: "Asia/Jerusalem", around: date(18, 12)))
        let query = url.absoluteString
        XCTAssertTrue(query.hasPrefix("https://www.hebcal.com/shabbat?"))
        XCTAssertTrue(query.contains("latitude=32.0853"))
        XCTAssertTrue(query.contains("longitude=34.7818"))
        XCTAssertTrue(query.contains("tzid=Asia/Jerusalem"))
        XCTAssertTrue(query.contains("dt=2026-10-18"))
    }

    func testWidgetSnapshotRoundTrips() throws {
        var snapshot = WidgetSnapshot()
        snapshot.alarms = [WakeAlarm(title: "Shabbat", hour: 7, minute: 0, repeatsWeekly: true, weekdays: [7])]
        snapshot.latitude = 32.0853
        snapshot.longitude = 34.7818
        snapshot.timeZoneIdentifier = "Asia/Jerusalem"
        snapshot.times = [ShabbatTimeItem(id: "a", title: "Havdalah", date: date(24, 17), category: "havdalah")]
        let data = try JSONEncoder().encode(snapshot)
        XCTAssertEqual(try JSONDecoder().decode(WidgetSnapshot.self, from: data), snapshot)
    }

    func testHebrewCalendarProducesAValidDate() {
        var calendar = Calendar(identifier: .hebrew)
        calendar.locale = Locale(identifier: "he")
        let parts = calendar.dateComponents([.year, .month, .day], from: Date.now)
        XCTAssertNotNil(parts.year)
        XCTAssertNotNil(parts.month)
        XCTAssertNotNil(parts.day)
    }

    func testAlarmSoundsAreBundledInTheApp() {
        let bundle = Bundle.main
        for name in ["GentleChime", "SunriseSequence", "ClassicWake"] {
            XCTAssertNotNil(bundle.url(forResource: name, withExtension: "wav"), "\(name).wav is missing from \(bundle.bundlePath)")
        }
    }

    func testWeeksAreBuiltFromCandlesParashaAndHavdalah() throws {
        let json = """
        {"items":[
          {"title":"Candle lighting: 17:18","date":"2026-10-23T17:18:00+03:00","category":"candles","hebrew":"הדלקת נרות"},
          {"title":"Parashat Lech-Lecha","date":"2026-10-24","category":"parashat","hebrew":"פרשת לך־לך"},
          {"title":"Havdalah: 18:34","date":"2026-10-24T18:34:00+03:00","category":"havdalah","hebrew":"הבדלה"},
          {"title":"Candle lighting: 16:11","date":"2026-10-30T16:11:00+02:00","category":"candles","hebrew":"הדלקת נרות"},
          {"title":"Parashat Vayera","date":"2026-10-31","category":"parashat","hebrew":"פרשת וירא"},
          {"title":"Havdalah: 17:28","date":"2026-10-31T17:28:00+02:00","category":"havdalah","hebrew":"הבדלה"}
        ]}
        """
        let weeks = try ShabbatTimesService.parseWeeks(Data(json.utf8), timeZoneIdentifier: "Asia/Jerusalem")
        XCTAssertEqual(weeks.count, 2)
        XCTAssertEqual(weeks[0].parashaEnglish, "Parashat Lech-Lecha")
        XCTAssertEqual(weeks[0].parashaHebrew, "פרשת לך־לך")
        XCTAssertEqual(weeks[0].id, "2026-10-24")
        let candle = ISO8601DateFormatter().date(from: "2026-10-23T17:18:00+03:00")
        let havdalah = ISO8601DateFormatter().date(from: "2026-10-24T18:34:00+03:00")
        XCTAssertEqual(weeks[0].candleLighting, candle)
        XCTAssertEqual(weeks[0].havdalah, havdalah)
        XCTAssertEqual(weeks[1].parashaEnglish, "Parashat Vayera")
    }

    func testLongerCandleLightingCustomsForJerusalemAndHaifa() {
        XCTAssertEqual(ShabbatTimesService.candleLightingMinutes(latitude: 31.7683, longitude: 35.2137), 40)
        XCTAssertEqual(ShabbatTimesService.candleLightingMinutes(latitude: 32.7940, longitude: 34.9896), 30)
        XCTAssertNil(ShabbatTimesService.candleLightingMinutes(latitude: 32.0853, longitude: 34.7818))
        XCTAssertNil(ShabbatTimesService.candleLightingMinutes(latitude: 40.7128, longitude: -74.0060))
    }

    func testLanguageChoiceDecidesDirection() {
        XCTAssertEqual(AppLanguage.effectiveCode(for: "he"), "he")
        XCTAssertEqual(AppLanguage.effectiveCode(for: "en"), "en")
        XCTAssertTrue(AppLanguage.isRightToLeft("he"))
        XCTAssertFalse(AppLanguage.isRightToLeft("en"))
    }

    func testFreeUsersGetOneReminderAndProGetsSeveral() {
        XCTAssertTrue(ProPolicy.canAddReminder(currentCount: 0, hasPro: false))
        XCTAssertFalse(ProPolicy.canAddReminder(currentCount: 1, hasPro: false))
        XCTAssertTrue(ProPolicy.canAddReminder(currentCount: 1, hasPro: true))
        XCTAssertFalse(ProPolicy.canAddReminder(currentCount: ProPolicy.maxReminders, hasPro: true))
        XCTAssertFalse(ProPolicy.canChooseReminderTime(hasPro: false))
        XCTAssertTrue(ProPolicy.reminderChoices.contains(ProPolicy.defaultReminderMinutes))
    }

    func testReminderPlanSkipsThePastAndIsSortedAndCapped() {
        let reminders = [ShabbatReminder(minutesBefore: 30), ShabbatReminder(minutesBefore: 60)]
        let past = date(16, 17)       // Friday already gone
        let nextFriday = date(23, 17)
        let following = date(30, 17)
        let now = date(20, 9)
        let plan = ReminderPlanner.plan(reminders: reminders, candleTimes: [past, nextFriday, following], now: now)
        XCTAssertEqual(plan.count, 4)
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
        XCTAssertEqual(plan.first?.fireDate, nextFriday.addingTimeInterval(-3600))
        XCTAssertEqual(Set(plan.map(\.id)).count, 4)
        XCTAssertEqual(ReminderPlanner.plan(reminders: reminders, candleTimes: [nextFriday, following], now: now, limit: 3).count, 3)
        XCTAssertTrue(ReminderPlanner.plan(reminders: [], candleTimes: [nextFriday], now: now).isEmpty)
    }

    func testReminderFiringExactlyNowIsSkipped() {
        let now = date(20, 9)
        let reminders = [ShabbatReminder(minutesBefore: 30)]
        XCTAssertTrue(ReminderPlanner.plan(reminders: reminders, candleTimes: [now.addingTimeInterval(30 * 60)], now: now).isEmpty)
    }
}
