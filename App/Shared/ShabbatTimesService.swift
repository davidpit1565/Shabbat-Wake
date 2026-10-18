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
    let candleLighting: Date?
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

    static func makeURL(latitude: Double, longitude: Double, timeZoneIdentifier: String, around date: Date? = nil) -> URL? {
        var components = URLComponents(string: "https://www.hebcal.com/shabbat")
        var items = [
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "tzid", value: timeZoneIdentifier),
            URLQueryItem(name: "M", value: "on")
        ]
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

    static func makeWeeksURL(latitude: Double, longitude: Double, timeZoneIdentifier: String, from start: Date, weeks: Int) -> URL? {
        let formatter = dayFormatter(timeZoneIdentifier: timeZoneIdentifier)
        let end = start.addingTimeInterval(Double(weeks) * 7 * 24 * 3600)
        var components = URLComponents(string: "https://www.hebcal.com/hebcal")
        var items = [
            URLQueryItem(name: "v", value: "1"),
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "s", value: "on"),
            URLQueryItem(name: "c", value: "on"),
            URLQueryItem(name: "maj", value: "off"),
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
        if let minutes = candleLightingMinutes(latitude: latitude, longitude: longitude) {
            items.append(URLQueryItem(name: "b", value: String(minutes)))
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

        return candles.map { candleDate, _ in
            let candleDay = calendar.startOfDay(for: candleDate)
            let window = candleDay...candleDay.addingTimeInterval(3 * 24 * 3600)
            let portion = portions.first { window.contains($0.0) }
            let havdalah = havdalot.first { $0 > candleDate && $0.timeIntervalSince(candleDate) < 3 * 24 * 3600 }
            let shabbat = portion?.0 ?? havdalah.map { calendar.startOfDay(for: $0) } ?? candleDay
            return ShabbatWeek(
                id: day.string(from: shabbat),
                parashaEnglish: portion?.1.title,
                parashaHebrew: portion?.1.hebrew,
                candleLighting: candleDate,
                havdalah: havdalah,
                shabbatDay: shabbat
            )
        }
    }

    static func fetchWeeks(latitude: Double, longitude: Double, timeZoneIdentifier: String, from start: Date = .now, weeks: Int = 26) async throws -> [ShabbatWeek] {
        guard let url = makeWeeksURL(latitude: latitude, longitude: longitude, timeZoneIdentifier: timeZoneIdentifier, from: start, weeks: weeks) else {
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
            if let havdalah = week.havdalah { list.append(ShabbatTimeItem(id: week.id + "h", title: "Havdalah", date: havdalah, category: "havdalah")) }
            return list
        }
    }
}
