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

    // MARK: Shabbat alarms (rings that stop by themselves)

    private func ringAlarm(weekdays: Set<Int> = [], repeats: Bool = false, weeks: Int? = nil, plan: RingPlan = RingPlan(count: 3, intervalMinutes: 5, seconds: 15), armed: Date) -> WakeAlarm {
        var alarm = WakeAlarm(title: "Shabbat", hour: 7, minute: 0, repeatsWeekly: repeats, weekdays: weekdays, ringPlan: plan, weeksLimit: weeks)
        alarm.armedAt = armed
        return alarm
    }

    func testOneTimeShabbatAlarmRingsTheChosenNumberOfTimes() {
        let now = date(23, 20)                          // Friday evening
        let alarm = ringAlarm(armed: now)
        let rings = RingPlanner.rings(for: alarm, now: now, calendar: calendar)
        XCTAssertEqual(rings.count, 3)
        XCTAssertEqual(rings.map(\.fireDate), [date(24, 7, 0), date(24, 7, 5), date(24, 7, 10)])
        XCTAssertTrue(rings.allSatisfy { !$0.repeats })
        XCTAssertEqual(Set(rings.map(\.id)).count, 3)
    }

    func testRingsAlreadyInThePastAreDropped() {
        let armed = date(23, 20)
        let alarm = ringAlarm(armed: armed)
        let rings = RingPlanner.rings(for: alarm, now: date(24, 7, 6), calendar: calendar)
        XCTAssertEqual(rings.map(\.fireDate), [date(24, 7, 10)])
    }

    func testWeeklyShabbatAlarmUsesRepeatingTriggersPerDay() {
        let now = date(20, 9)                           // Tuesday
        let alarm = ringAlarm(weekdays: [7, 1], repeats: true, armed: now)
        let rings = RingPlanner.rings(for: alarm, now: now, calendar: calendar)
        XCTAssertEqual(rings.count, 6)
        XCTAssertTrue(rings.allSatisfy(\.repeats))
        let saturday = rings.filter { $0.components.weekday == 7 }
        XCTAssertEqual(saturday.map { $0.components.minute }, [0, 5, 10])
    }

    func testRingsCrossingMidnightMoveToTheNextWeekday() {
        var alarm = ringAlarm(weekdays: [7], repeats: true, plan: RingPlan(count: 3, intervalMinutes: 15, seconds: 10), armed: date(20, 9))
        alarm.hour = 23; alarm.minute = 50
        let rings = RingPlanner.rings(for: alarm, now: date(20, 9), calendar: calendar)
        XCTAssertEqual(rings.map { $0.components.weekday }, [7, 1, 1])
        XCTAssertEqual(rings.map { $0.components.minute }, [50, 5, 20])
    }

    func testAlarmLimitedToWeeksStopsAfterThem() {
        let armed = date(20, 9)
        let alarm = ringAlarm(weekdays: [7], repeats: true, weeks: 2, plan: RingPlan(count: 1, intervalMinutes: 5, seconds: 10), armed: armed)
        let rings = RingPlanner.rings(for: alarm, now: armed, calendar: calendar)
        XCTAssertEqual(rings.map(\.fireDate), [date(24, 7), calendar.date(byAdding: .day, value: 7, to: date(24, 7))!])
        XCTAssertNotNil(alarm.nextFireDate(after: armed, calendar: calendar))
        XCTAssertNil(alarm.nextFireDate(after: date(24, 8).addingTimeInterval(8 * 86400), calendar: calendar))
    }

    func testRingPlannerStaysWithinBudgetAndIgnoresPlainAlarms() {
        let armed = date(20, 9)
        let big = ringAlarm(weekdays: [7], repeats: true, weeks: 26, plan: RingPlan(count: 10, intervalMinutes: 1, seconds: 10), armed: armed)
        XCTAssertLessThanOrEqual(RingPlanner.rings(for: big, now: armed, calendar: calendar).count, ShabbatAlarmService.budget)
        var plain = WakeAlarm(title: "x", hour: 7, minute: 0, repeatsWeekly: false, weekdays: [])
        plain.armedAt = armed
        XCTAssertTrue(RingPlanner.rings(for: plain, now: armed, calendar: calendar).isEmpty)
    }

    func testRingPlanValuesAreKeptInsideWhatTheAppOffers() {
        let odd = RingPlan(count: 99, intervalMinutes: 7, seconds: 45).normalized()
        XCTAssertEqual(odd, RingPlan(count: 10, intervalMinutes: 5, seconds: 15))
        XCTAssertEqual(RingPlan(count: 0, intervalMinutes: 1, seconds: 10).normalized().count, 1)
    }

    func testOldSavedAlarmsStillDecodeAsSystemAlarms() throws {
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","title":"Old","hour":7,"minute":0,"repeatsWeekly":false,"weekdays":[],"isEnabled":true,"soundID":"classic","createdAt":0}"#
        let alarm = try JSONDecoder().decode(WakeAlarm.self, from: Data(json.utf8))
        XCTAssertNil(alarm.ringPlan)
        XCTAssertNil(alarm.weeksLimit)
    }

    func testShabbatAlarmSoundFilesMatchTheChosenLength() {
        var alarm = WakeAlarm(title: "x", hour: 7, minute: 0, repeatsWeekly: false, weekdays: [], soundID: "gentle", ringPlan: RingPlan(count: 2, intervalMinutes: 5, seconds: 20))
        XCTAssertEqual(ShabbatAlarmService.soundFileName(for: alarm), "GentleChime_20s.wav")
        alarm.soundID = "classic"; alarm.ringPlan = RingPlan(count: 2, intervalMinutes: 5, seconds: 10)
        XCTAssertEqual(ShabbatAlarmService.soundFileName(for: alarm), "ClassicWake_10s.wav")
        for tone in ["ClassicWake", "GentleChime", "SunriseSequence"] {
            for seconds in RingPlan.secondChoices {
                XCTAssertNotNil(Bundle.main.url(forResource: "\(tone)_\(seconds)s", withExtension: "wav"), "\(tone)_\(seconds)s.wav is not in the app")
            }
        }
    }

    func testYomTovChainBecomesOneStretchWithTheHolidayName() throws {
        let json = """
        {"items":[
          {"title":"Candle lighting: 18:30","date":"2026-09-11T18:30:00+03:00","category":"candles","hebrew":"הדלקת נרות"},
          {"title":"Rosh Hashana 5787","date":"2026-09-12","category":"holiday","yomtov":true,"hebrew":"ראש השנה 5787"},
          {"title":"Candle lighting: 19:25","date":"2026-09-12T19:25:00+03:00","category":"candles","hebrew":"הדלקת נרות"},
          {"title":"Rosh Hashana II","date":"2026-09-13","category":"holiday","yomtov":true,"hebrew":"ראש השנה ב׳"},
          {"title":"Havdalah: 19:22","date":"2026-09-13T19:22:00+03:00","category":"havdalah","hebrew":"הבדלה"},
          {"title":"Erev Yom Kippur","date":"2026-09-20","category":"holiday","hebrew":"ערב יום כפור"}
        ]}
        """
        let weeks = try ShabbatTimesService.parseWeeks(Data(json.utf8), timeZoneIdentifier: "Asia/Jerusalem")
        XCTAssertEqual(weeks.count, 1)
        XCTAssertEqual(weeks[0].holidayEnglish, "Rosh Hashana")
        XCTAssertEqual(weeks[0].holidayHebrew, "ראש השנה")
        XCTAssertNil(weeks[0].parashaEnglish)
        XCTAssertEqual(weeks[0].candleLighting, ISO8601DateFormatter().date(from: "2026-09-11T18:30:00+03:00"))
        XCTAssertEqual(weeks[0].havdalah, ISO8601DateFormatter().date(from: "2026-09-13T19:22:00+03:00"))
    }

    func testPlainShabbatHasNoHolidayName() throws {
        XCTAssertNil(ShabbatTimesService.holidayName([], hebrew: false))
        XCTAssertEqual(ShabbatTimesService.holidayName(["Sukkot I", "Sukkot II"], hebrew: false), "Sukkot")
        XCTAssertEqual(ShabbatTimesService.holidayName(["Pesach I", "Shavuot II"], hebrew: false), "Pesach · Shavuot")
    }

    func testHebrewNumeralsUseLettersWithGeresh() {
        XCTAssertEqual(HebrewDateFormat.numeral(7), "ז׳")
        XCTAssertEqual(HebrewDateFormat.numeral(15), "ט״ו")
        XCTAssertEqual(HebrewDateFormat.numeral(16), "ט״ז")
        XCTAssertEqual(HebrewDateFormat.numeral(29), "כ״ט")
        XCTAssertEqual(HebrewDateFormat.numeral(30), "ל׳")
        XCTAssertEqual(HebrewDateFormat.numeral(787), "תשפ״ז")
    }

    func testHebrewDateInHebrewIsLettersAndEnglishKeepsDigits() {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone.current
        let day = gregorian.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 12))!   // 7 Cheshvan 5787
        let hebrew = day.hebrewDateString(in: Locale(identifier: "he"))
        XCTAssertTrue(hebrew.hasPrefix("ז׳ "), hebrew)
        XCTAssertTrue(hebrew.hasSuffix("תשפ״ז"), hebrew)
        let english = day.hebrewDateString(in: Locale(identifier: "en"))
        XCTAssertTrue(english.contains("5787"), english)
        XCTAssertTrue(english.hasPrefix("7 ") && english.contains("Heshvan"), english)
    }

    func testEveryLanguageIsOfferedAndHasItsStrings() {
        for code in AppLanguage.supportedCodes {
            XCTAssertEqual(AppLanguage.effectiveCode(for: code), code)
            let path = Bundle.main.path(forResource: code, ofType: "lproj")
            XCTAssertNotNil(path, "\(code).lproj is missing from the app")
            guard let path, let bundle = Bundle(path: path) else { continue }
            let translated = bundle.localizedString(forKey: "Send feedback", value: "MISSING", table: nil)
            XCTAssertNotEqual(translated, "MISSING", "\(code) has no translation for 'Send feedback'")
        }
        XCTAssertTrue(AppLanguage.isRightToLeft("he"))
        for code in ["en", "ru", "fr", "es"] { XCTAssertFalse(AppLanguage.isRightToLeft(code)) }
    }

    func testSavedPlacesArePro() {
        XCTAssertFalse(ProPolicy.canSavePlace(currentCount: 0, hasPro: false))
        XCTAssertTrue(ProPolicy.canSavePlace(currentCount: 0, hasPro: true))
        XCTAssertFalse(ProPolicy.canSavePlace(currentCount: ProPolicy.maxSavedPlaces, hasPro: true))
    }

    func testHebcalIsAskedForNamesInTheAppLanguage() {
        func query(_ language: String) -> [String: String] {
            let url = ShabbatTimesService.makeWeeksURL(latitude: 31.77, longitude: 35.21, timeZoneIdentifier: "Asia/Jerusalem", from: Date(timeIntervalSince1970: 1_790_000_000), weeks: 4, language: language)!
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        }
        XCTAssertEqual(query("ru")["lg"], "ru")
        XCTAssertEqual(query("fr")["lg"], "fr")
        XCTAssertEqual(query("es")["lg"], "es")
        XCTAssertNil(query("en")["lg"])
        XCTAssertNil(query("he")["lg"])
        XCTAssertEqual(query("en")["maj"], "on")
    }

    func testSavedPlaceSurvivesEncoding() throws {
        let place = SavedPlace(name: "Paris, France", latitude: 48.85, longitude: 2.35, timeZoneIdentifier: "Europe/Paris")
        let decoded = try JSONDecoder().decode(SavedPlace.self, from: JSONEncoder().encode(place))
        XCTAssertEqual(decoded, place)
    }
}
