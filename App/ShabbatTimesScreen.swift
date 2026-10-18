import CoreLocation
import SwiftUI
import UIKit

@MainActor
final class ShabbatLocationModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var authorization: CLAuthorizationStatus
    @Published private(set) var placeName: String?
    @Published private(set) var weeks: [ShabbatWeek] = []
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
            errorMessage = AppLanguage.text("Location access is required to calculate local Shabbat times. Enable it in Settings.")
        @unknown default:
            errorMessage = AppLanguage.text("Location permission status is unavailable.")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedAlways || authorization == .authorizedWhenInUse {
            manager.requestLocation()
        } else if authorization == .denied || authorization == .restricted {
            weeks = []
            placeName = nil
            WidgetSync.clearLocation()
            errorMessage = AppLanguage.text("Location access is required. No local times will be calculated without it.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, latest.horizontalAccuracy >= 0, latest.horizontalAccuracy < 20000 else {
            errorMessage = AppLanguage.text("Could not get a reliable location. Try again.")
            return
        }
        Task { await fetchTimes(for: latest) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = AppLanguage.text("Could not get your location. Check Location Services and try again.")
        isLoading = false
        weeks = []
    }

    func refresh() { requestLocation() }

    private func fetchTimes(for location: CLLocation) async {
        let fetchID = UUID()
        activeFetchID = fetchID
        isLoading = true
        errorMessage = nil
        weeks = []
        placeName = nil
        do {
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
            guard activeFetchID == fetchID else { return }
            let mark = placemarks?.first
            let name = [mark?.locality, mark?.administrativeArea].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            placeName = name.isEmpty ? nil : name
            let zone = mark?.timeZone?.identifier ?? TimeZone.current.identifier
            // Start from yesterday so the Shabbat that is under way right now is still listed.
            let start = Date.now.addingTimeInterval(-24 * 3600)
            let fetched = try await ShabbatTimesService.fetchWeeks(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timeZoneIdentifier: zone,
                from: start,
                weeks: 27
            ).filter { ($0.havdalah ?? $0.shabbatDay.addingTimeInterval(24 * 3600)) > .now }
            guard activeFetchID == fetchID else { return }
            weeks = fetched
            WidgetSync.updateLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timeZoneIdentifier: zone,
                placeName: placeName,
                times: fetched.timeItems
            )
            if fetched.isEmpty {
                errorMessage = AppLanguage.text("No Shabbat times were returned for this location and date range.")
            }
        } catch {
            guard activeFetchID == fetchID else { return }
            errorMessage = AppLanguage.text("Shabbat times could not be loaded. Check your connection and try again.")
            weeks = []
        }
        guard activeFetchID == fetchID else { return }
        isLoading = false
    }
}

struct ShabbatTimesScreen: View {
    @StateObject private var model = ShabbatLocationModel()
    @Environment(\.locale) private var locale

    private var isAuthorized: Bool {
        model.authorization == .authorizedAlways || model.authorization == .authorizedWhenInUse
    }
    private var isHebrew: Bool { locale.identifier.hasPrefix("he") }

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

                if model.isLoading {
                    Section { ProgressView("Loading times for your location…") }
                } else if model.weeks.isEmpty {
                    Section {
                        ContentUnavailableView("Times unavailable", systemImage: "sun.horizon", description: Text(model.errorMessage ?? AppLanguage.text("Allow location access to calculate times.")))
                    }
                } else {
                    if let first = model.weeks.first {
                        Section {
                            weekRow(first, prominent: true)
                        } header: {
                            let heading = AppLanguage.text(first.parashaEnglish == nil && first.holidayEnglish != nil ? "Next holiday" : "This Shabbat")
                            Text(model.placeName.map { "\(heading) · \($0)" } ?? heading)
                        }
                    }
                    if model.weeks.count > 1 {
                        Section("Coming Shabbatot") {
                            ForEach(model.weeks.dropFirst()) { week in
                                weekRow(week, prominent: false)
                            }
                        }
                    }
                }

                Section {
                    EmptyView()
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

    private func weekRow(_ week: ShabbatWeek, prominent: Bool) -> some View {
        let parasha = isHebrew ? (week.parashaHebrew ?? week.parashaEnglish) : (week.parashaEnglish ?? week.parashaHebrew)
        let holiday = isHebrew ? (week.holidayHebrew ?? week.holidayEnglish) : (week.holidayEnglish ?? week.holidayHebrew)
        let portion = [parasha, holiday].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: prominent ? 12 : 8) {
            VStack(alignment: .leading, spacing: 2) {
                if !portion.isEmpty {
                    Text(portion).font(prominent ? .title3.weight(.semibold) : .headline)
                }
                Text(week.shabbatDay.formatted(in: locale, date: .complete))
                    .font(.caption).foregroundStyle(.secondary)
                Text(week.shabbatDay.hebrewDateString(in: locale))
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 24) {
                timeColumn("Candle lighting", symbol: "flame", date: week.candleLighting, prominent: prominent)
                timeColumn("Shabbat ends", symbol: "moon.stars", date: week.havdalah, prominent: prominent)
            }
        }
        .padding(.vertical, 4)
    }

    private func timeColumn(_ title: LocalizedStringKey, symbol: String, date: Date?, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.caption).foregroundStyle(.secondary)
            Text(date?.formatted(in: locale, time: .shortened) ?? "—")
                .font((prominent ? Font.title2 : Font.title3).monospacedDigit().weight(.semibold))
        }
    }
}
