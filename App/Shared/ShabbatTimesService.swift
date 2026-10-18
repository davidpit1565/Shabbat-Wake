import Foundation

struct ShabbatTimeItem: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let date: Date
    let category: String
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
}
