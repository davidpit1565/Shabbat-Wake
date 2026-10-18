import CoreLocation
import SwiftUI
import UIKit

@MainActor
final class ShabbatLocationModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var authorization: CLAuthorizationStatus
    @Published private(set) var location: CLLocation?
    @Published private(set) var placeName: String?
    @Published private(set) var times: [ShabbatTimeItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private let manager = CLLocationManager()

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted:
            errorMessage = String(localized: "Location access is required to calculate local Shabbat times. Enable it in Settings.")
        @unknown default:
            errorMessage = String(localized: "Location permission status is unavailable.")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedAlways || authorization == .authorizedWhenInUse {
            manager.requestLocation()
        } else if authorization == .denied || authorization == .restricted {
            location = nil
            times = []
            errorMessage = String(localized: "Location access is required. No local times will be calculated without it.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, latest.horizontalAccuracy >= 0, latest.horizontalAccuracy < 20000 else {
            errorMessage = String(localized: "Could not get a reliable location. Try again.")
            return
        }
        location = latest
        Task { await fetchTimes(for: latest) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = String(localized: "Could not get your location. Check Location Services and try again.")
        isLoading = false
        times = []
    }

    func refresh() { requestLocation() }

    private func fetchTimes(for location: CLLocation) async {
        isLoading = true
        errorMessage = nil
        times = []
        do {
            let geocoder = CLGeocoder()
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            placeName = placemarks?.first.map { mark in
                [mark.locality, mark.administrativeArea, mark.isoCountryCode]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            }
            let locationTimeZone = placemarks?.first?.timeZone?.identifier ?? TimeZone.current.identifier
            guard let url = makeURL(location: location, timeZoneIdentifier: locationTimeZone) else { throw URLError(.badURL) }
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let decoded = try JSONDecoder().decode(HebcalResponse.self, from: data)
            times = decoded.items.compactMap { item in
                guard let date = ISO8601DateFormatter().date(from: item.date) else { return nil }
                guard ["candles", "havdalah"].contains(item.category ?? "") else { return nil }
                return ShabbatTimeItem(id: item.title + item.date, title: item.title, date: date, category: item.category ?? "")
            }.sorted { $0.date < $1.date }
            if times.isEmpty {
                errorMessage = String(localized: "No Shabbat times were returned for this location and date range.")
            }
        } catch {
            errorMessage = String(localized: "Shabbat times could not be loaded. Check your connection and try again.")
            times = []
        }
        isLoading = false
    }

    private func makeURL(location: CLLocation, timeZoneIdentifier: String) -> URL? {
        var components = URLComponents(string: "https://www.hebcal.com/shabbat")
        components?.queryItems = [
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "tzid", value: timeZoneIdentifier),
            URLQueryItem(name: "M", value: "on")
        ]
        return components?.url
    }
}

private struct HebcalResponse: Decodable {
    let items: [HebcalItem]
}
private struct HebcalItem: Decodable {
    let title: String
    let date: String
    let category: String?
}
struct ShabbatTimeItem: Identifiable {
    let id: String
    let title: String
    let date: Date
    let category: String
}

struct ShabbatTimesScreen: View {
    @StateObject private var model = ShabbatLocationModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Location permission is required", systemImage: "location.fill")
                        .font(.headline)
                    Text("Local Shabbat times are calculated only after iOS grants location access. If permission is denied or no location is available, this screen shows no calculated times.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button {
                        model.refresh()
                    } label: {
                        Label(model.authorization == .denied ? "Open iOS Settings" : "Allow / refresh location", systemImage: "location.circle")
                    }
                    if model.authorization == .denied || model.authorization == .restricted {
                        Button("Open Settings") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                    }
                }
                if let location = model.location {
                    Section("Current location") {
                        LabeledContent("Latitude", value: location.coordinate.latitude.formatted(.number.precision(.fractionLength(4))))
                        LabeledContent("Longitude", value: location.coordinate.longitude.formatted(.number.precision(.fractionLength(4))))
                        if let placeName = model.placeName { LabeledContent("Area", value: placeName) }
                    }
                }
                Section("Shabbat times") {
                    if model.isLoading {
                        ProgressView("Loading times for your location…")
                    } else if model.times.isEmpty {
                        ContentUnavailableView("Times unavailable", systemImage: "sun.horizon", description: Text(model.errorMessage ?? "Allow location access to calculate times."))
                    } else {
                        ForEach(model.times) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title).font(.headline)
                                    Text(item.date.formatted(date: .complete, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.date.formatted(date: .omitted, time: .shortened))
                                    .font(.title3.monospacedDigit().weight(.semibold))
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
            .navigationTitle("Shabbat times")
            .task {
                if model.authorization == .notDetermined { model.requestLocation() }
                else if model.authorization == .authorizedAlways || model.authorization == .authorizedWhenInUse { model.refresh() }
            }
        }
    }
}
