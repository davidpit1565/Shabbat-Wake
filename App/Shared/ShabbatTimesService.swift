import Foundation

struct ShabbatTimeItem: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let date: Date
    let category: String
}

/// One Shabbat: its Torah portion, candle lighting before it and havdalah after it.
struct ShabbatWeek: Identifiable, Equatable, Codable {
    let id: String
    let parashaEnglish: String?
    let parashaHebrew: String?
    /// Set when the days around this candle lighting include a Yom Tov, for example "Rosh Hashana".
    var holidayEnglish: String? = nil
    var holidayHebrew: String? = nil
    let candleLighting: Date?
    /// Later candle lightings of the same stretch, for example Thursday night and Friday after Rosh Hashana on Wednesday night.
    var laterCandleLightings: [Date]? = nil
    let havdalah: Date?
    /// The Shabbat day itself (midnight in the location's time zone).
    let shabbatDay: Date
}

/// Fetches candle-lighting and havdalah times from Hebcal. Shared by the app and the widget extension.
enum ShabbatTimesService {
    private struct Response: Decodable {
        let items: [Item]
    }
    private struct Item: Decodable {
        let title: String
        let date: String
        let category: String?
        let hebrew: String?
        let yomtov: Bool?
    }

    /// Communities with a longer candle-lighting custom (same table the Bet-El app uses: Jerusalem 40, Haifa 30, Zichron Yaakov 30).
    /// Returns nil where Hebcal's default of 18 minutes applies.
    static func candleLightingMinutes(latitude: Double, longitude: Double) -> Int? {
        let cities: [(lat: Double, lon: Double, radiusKm: Double, minutes: Int)] = [
            (31.7690, 35.2163, 12, 40),
            (32.7940, 34.9896, 12, 30),
            (32.5700, 34.9500, 6, 30)
        ]
        for city in cities {
            let dLat = (latitude - city.lat) * .pi / 180
            let dLon = (longitude - city.lon) * .pi / 180
            let a = pow(sin(dLat / 2), 2) + cos(city.lat * .pi / 180) * cos(latitude * .pi / 180) * pow(sin(dLon / 2), 2)
            let km = 6371 * 2 * atan2(sqrt(a), sqrt(1 - a))
            if km <= city.radiusKm { return city.minutes }
        }
        return nil
    }

    /// Hebcal keeps the diaspora calendar (two-day holidays, different readings) unless it is asked for Israel's.
    static func isIsrael(timeZoneIdentifier: String) -> Bool {
        ["Asia/Jerusalem", "Asia/Tel_Aviv", "Israel", "Asia/Hebron", "Asia/Gaza"].contains(timeZoneIdentifier)
    }

    static func makeURL(latitude: Double, longitude: Double, timeZoneIdentifier: String, around date: Date? = nil) -> URL? {
        var components = URLComponents(string: "https://www.hebcal.com/shabbat")
        var items = [
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "geo", value: "pos"),
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "tzid", value: timeZoneIdentifier),
            URLQueryItem(name: "M", value: "on")
        ]
        if isIsrael(timeZoneIdentifier: timeZoneIdentifier) { items.append(URLQueryItem(name: "i", value: "on")) }
        if let minutes = candleLightingMinutes(latitude: latitude, longitude: longitude) {
            items.append(URLQueryItem(name: "b", value: String(minutes)))
        }
        if let date {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
            formatter.dateFormat = "yyyy-MM-dd"
            items.append(URLQueryItem(name: "dt", value: formatter.string(from: date)))
        }
        components?.queryItems = items
        return components?.url
    }

    static func parse(_ data: Data) throws -> [ShabbatTimeItem] {
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let formatter = ISO8601DateFormatter()
        return decoded.items.compactMap { item in
            guard let category = item.category, ["candles", "havdalah"].contains(category) else { return nil }
            guard let date = formatter.date(from: item.date) else { return nil }
            return ShabbatTimeItem(id: item.title + item.date, title: item.title, date: date, category: category)
        }.sorted { $0.date < $1.date }
    }

    static func fetch(latitude: Double, longitude: Double, timeZoneIdentifier: String, around date: Date? = nil) async throws -> [ShabbatTimeItem] {
        guard let url = makeURL(latitude: latitude, longitude: longitude, timeZoneIdentifier: timeZoneIdentifier, around: date) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try parse(data)
    }

    // MARK: Several weeks ahead

    /// Hebcal can name parashiyot and holidays in these app languages; English and Hebrew need no `lg` (Hebrew comes in its own field).
    static func hebcalLanguage(for appLanguage: String) -> String? {
        ["ru", "fr", "es"].contains(appLanguage) ? appLanguage : nil
    }

    static func makeWeeksURL(latitude: Double, longitude: Double, timeZoneIdentifier: String, from start: Date, weeks: Int, language: String = "en") -> URL? {
        let formatter = dayFormatter(timeZoneIdentifier: timeZoneIdentifier)
        let end = start.addingTimeInterval(Double(weeks) * 7 * 24 * 3600)
        var components = URLComponents(string: "https://www.hebcal.com/hebcal")
        var items = [
            URLQueryItem(name: "v", value: "1"),
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "s", value: "on"),
            URLQueryItem(name: "c", value: "on"),
            URLQueryItem(name: "maj", value: "on"),
            URLQueryItem(name: "min", value: "off"),
            URLQueryItem(name: "nx", value: "off"),
            URLQueryItem(name: "mf", value: "off"),
            URLQueryItem(name: "ss", value: "off"),
            URLQueryItem(name: "mod", value: "off"),
            URLQueryItem(name: "geo", value: "pos"),
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "tzid", value: timeZoneIdentifier),
            URLQueryItem(name: "M", value: "on"),
            URLQueryItem(name: "start", value: formatter.string(from: start)),
            URLQueryItem(name: "end", value: formatter.string(from: end))
        ]
        if isIsrael(timeZoneIdentifier: timeZoneIdentifier) { items.append(URLQueryItem(name: "i", value: "on")) }
        if let minutes = candleLightingMinutes(latitude: latitude, longitude: longitude) {
            items.append(URLQueryItem(name: "b", value: String(minutes)))
        }
        if let lg = hebcalLanguage(for: language) {
            items.append(URLQueryItem(name: "lg", value: lg))
        }
        components?.queryItems = items
        return components?.url
    }

    static func parseWeeks(_ data: Data, timeZoneIdentifier: String) throws -> [ShabbatWeek] {
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let iso = ISO8601DateFormatter()
        let day = dayFormatter(timeZoneIdentifier: timeZoneIdentifier)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current

        let candles = decoded.items.filter { $0.category == "candles" }.compactMap { item in iso.date(from: item.date).map { ($0, item) } }.sorted { $0.0 < $1.0 }
        let havdalot = decoded.items.filter { $0.category == "havdalah" }.compactMap { item in iso.date(from: item.date) }.sorted()
        let portions = decoded.items.filter { $0.category == "parashat" }.compactMap { item in day.date(from: item.date).map { ($0, item) } }
        let yomTovDays = decoded.items.filter { $0.category == "holiday" && $0.yomtov == true }.compactMap { item in day.date(from: item.date).map { ($0, item) } }

        // Candles lit on consecutive evenings with no havdalah in between (Yom Tov, then Shabbat) are one stretch.
        var blocks: [[Date]] = []
        for (candleDate, _) in candles {
            if let last = blocks.last?.last, !havdalot.contains(where: { $0 > last && $0 < candleDate }) {
                blocks[blocks.count - 1].append(candleDate)
            } else {
                blocks.append([candleDate])
            }
        }

        return blocks.compactMap { block -> ShabbatWeek? in
            guard let candleDate = block.first, let lastCandle = block.last else { return nil }
            let firstDay = calendar.startOfDay(for: candleDate)
            let havdalah = havdalot.first { $0 > lastCandle && $0.timeIntervalSince(lastCandle) < 3 * 24 * 3600 }
            let endDay = havdalah.map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: lastCandle).addingTimeInterval(24 * 3600)
            let window = firstDay..<max(firstDay.addingTimeInterval(3 * 24 * 3600), endDay.addingTimeInterval(1))
            let portion = portions.first { window.contains($0.0) }
            let holidays = yomTovDays.filter { (firstDay...endDay).contains($0.0) }
            let shabbat = portion?.0 ?? havdalah.map { calendar.startOfDay(for: $0) } ?? firstDay
            return ShabbatWeek(
                id: day.string(from: shabbat) + (portion == nil ? "-yt" : ""),
                parashaEnglish: portion?.1.title,
                parashaHebrew: portion?.1.hebrew,
                holidayEnglish: holidayName(holidays.map { $0.1.title }, hebrew: false),
                holidayHebrew: holidayName(holidays.map { $0.1.hebrew ?? $0.1.title }, hebrew: true),
                candleLighting: candleDate,
                laterCandleLightings: block.count > 1 ? Array(block.dropFirst()) : nil,
                havdalah: havdalah,
                shabbatDay: shabbat
            )
        }
    }

    /// "Rosh Hashana 5787" and "Rosh Hashana II" both become "Rosh Hashana"; several days of one holiday are listed once.
    static func holidayName(_ titles: [String], hebrew: Bool) -> String? {
        var names: [String] = []
        for title in titles {
            var name = title
            name = name.replacingOccurrences(of: #"\s+\d{4}$"#, with: "", options: .regularExpression)
            name = name.replacingOccurrences(of: hebrew ? #"\s+[א-ת]׳$"# : #"\s+[IVX]+$"#, with: "", options: .regularExpression)
            name = name.replacingOccurrences(of: #"\s*\(.*\)$"#, with: "", options: .regularExpression)
            name = name.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty && !names.contains(name) { names.append(name) }
        }
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }

    static func fetchWeeks(latitude: Double, longitude: Double, timeZoneIdentifier: String, from start: Date = .now, weeks: Int = 26, language: String = "en") async throws -> [ShabbatWeek] {
        guard let url = makeWeeksURL(latitude: latitude, longitude: longitude, timeZoneIdentifier: timeZoneIdentifier, from: start, weeks: weeks, language: language) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try parseWeeks(data, timeZoneIdentifier: timeZoneIdentifier)
    }

    private static func dayFormatter(timeZoneIdentifier: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

extension Array where Element == ShabbatWeek {
    /// Candle-lighting and havdalah entries for the saved snapshot, widgets and reminders.
    var timeItems: [ShabbatTimeItem] {
        flatMap { week -> [ShabbatTimeItem] in
            var list: [ShabbatTimeItem] = []
            if let candle = week.candleLighting { list.append(ShabbatTimeItem(id: week.id + "c", title: "Candle lighting", date: candle, category: "candles")) }
            for (index, later) in (week.laterCandleLightings ?? []).enumerated() {
                list.append(ShabbatTimeItem(id: week.id + "c\(index + 2)", title: "Candle lighting", date: later, category: "candles"))
            }
            if let havdalah = week.havdalah { list.append(ShabbatTimeItem(id: week.id + "h", title: "Havdalah", date: havdalah, category: "havdalah")) }
            return list
        }
    }
}

extension ShabbatWeek {
    /// "Parashat Lech-Lecha", a holiday name, or both, in the given app language.
    func displayTitle(language: String) -> String {
        let hebrew = language == "he"
        let parasha = hebrew ? (parashaHebrew ?? parashaEnglish) : (parashaEnglish ?? parashaHebrew)
        let holiday = hebrew ? (holidayHebrew ?? holidayEnglish) : (holidayEnglish ?? holidayHebrew)
        return [parasha, holiday].compactMap { $0 }.joined(separator: " · ")
    }
}
