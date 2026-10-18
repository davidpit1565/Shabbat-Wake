import CoreLocation
import Foundation
import MapKit

/// A place the person keeps times for besides where they are right now, for example home, family or a trip.
struct SavedPlace: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String
}

/// Saved places and which one is shown. `activeID == nil` means "where I am now".
@MainActor
final class PlaceStore: ObservableObject {
    @Published private(set) var places: [SavedPlace] = []
    @Published private(set) var activeID: UUID?

    private let placesKey = "shabbatWake.places.v1"
    private let activeKey = "shabbatWake.activePlace.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: placesKey),
           let saved = try? JSONDecoder().decode([SavedPlace].self, from: data) {
            places = saved
        }
        if let text = UserDefaults.standard.string(forKey: activeKey), let id = UUID(uuidString: text), places.contains(where: { $0.id == id }) {
            activeID = id
        }
    }

    var activePlace: SavedPlace? { places.first { $0.id == activeID } }

    func add(_ place: SavedPlace) {
        guard !places.contains(where: { abs($0.latitude - place.latitude) < 0.01 && abs($0.longitude - place.longitude) < 0.01 }) else { return }
        places.append(place)
        persist()
    }

    func select(_ id: UUID?) {
        activeID = (id != nil && places.contains { $0.id == id }) ? id : nil
        UserDefaults.standard.set(activeID?.uuidString, forKey: activeKey)
    }

    func remove(_ id: UUID) {
        places.removeAll { $0.id == id }
        if activeID == id { select(nil) }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(places) { UserDefaults.standard.set(data, forKey: placesKey) }
    }
}

/// Looks a place up by name, for the "add a place" sheet.
enum PlaceSearch {
    struct Result: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let place: SavedPlace
    }

    static func search(_ text: String) async -> [Result] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.prefix(8).compactMap { item -> Result? in
            let mark = item.placemark
            let city = mark.locality ?? item.name ?? query
            let area = [mark.administrativeArea, mark.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            let zone = item.timeZone?.identifier ?? mark.timeZone?.identifier ?? TimeZone.current.identifier
            let place = SavedPlace(
                name: [city, mark.country].compactMap { $0 }.joined(separator: ", "),
                latitude: mark.coordinate.latitude,
                longitude: mark.coordinate.longitude,
                timeZoneIdentifier: zone
            )
            return Result(title: city, subtitle: area, place: place)
        }
    }
}
