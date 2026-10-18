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
    private var activeFetchID = UUID()

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
            WidgetSync.clearLocation()
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
        let fetchID = UUID()
        activeFetchID = fetchID
        isLoading = true
        errorMessage = nil
        times = []
        placeName = nil
        do {
            let geocoder = CLGeocoder()
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            guard activeFetchID == fetchID else { return }
            let name = placemarks?.first.map { mark in
                [mark.locality, mark.administrativeArea, mark.isoCountryCode]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            }
            placeName = name
            let locationTimeZone = placemarks?.first?.timeZone?.identifier ?? TimeZone.current.identifier
            var fetched = try await ShabbatTimesService.fetch(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timeZoneIdentifier: locationTimeZone
            )
            if !fetched.isEmpty, fetched.allSatisfy({ $0.date <= .now }) {
                // This week's Shabbat is over; show the coming one.
                fetched = try await ShabbatTimesService.fetch(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    timeZoneIdentifier: locationTimeZone,
                    around: Date.now.addingTimeInterval(24 * 60 * 60)
                )
            }
            guard activeFetchID == fetchID else { return }
            times = fetched
            WidgetSync.updateLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timeZoneIdentifier: locationTimeZone,
                placeName: name,
                times: fetched
            )
            if times.isEmpty {
                errorMessage = String(localized: "No Shabbat times were returned for this location and date range.")
            }
        } catch {
            guard activeFetchID == fetchID else { return }
            errorMessage = String(localized: "Shabbat times could not be loaded. Check your connection and try again.")
            times = []
        }
        guard activeFetchID == fetchID else { return }
        isLoading = false
    }
}

struct ShabbatTimesScreen: View {
    @StateObject private var model = ShabbatLocationModel()

    private var isAuthorized: Bool {
        model.authorization == .authorizedAlways || model.authorization == .authorizedWhenInUse
    }

    var body: some View {
        NavigationStack {
            List {
                if !isAuthorized {
                    Section {
                        Label("Location permission is required", systemImage: "location.fill")
                            .font(.headline)
                        Text("Shabbat times are calculated for your current location. Without location access, no times are shown.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if model.authorization == .denied || model.authorization == .restricted {
                            Button("Open Settings") {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                UIApplication.shared.open(url)
                            }
                        } else {
                            Button {
                                model.refresh()
                            } label: {
                                Label("Allow location", systemImage: "location.circle")
                            }
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
                Section {
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
                } header: {
                    Text("Shabbat times")
                } footer: {
                    Text("Times by [Hebcal.com](https://www.hebcal.com), licensed CC BY 4.0. Your coordinates are sent to Hebcal to calculate them. Times are provided for convenience; customs differ, so confirm with your rabbi or local calendar.")
                }
            }
            .navigationTitle("Shabbat times")
            .toolbar {
                if isAuthorized {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            model.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Refresh times")
                    }
                }
            }
            .task {
                if model.authorization == .notDetermined { model.requestLocation() }
                else if isAuthorized { model.refresh() }
            }
        }
    }
}
