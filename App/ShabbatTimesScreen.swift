import CoreLocation
import MapKit
import SwiftUI
import UIKit

@MainActor
final class ShabbatLocationModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var authorization: CLAuthorizationStatus
    @Published private(set) var placeName: String?
    @Published private(set) var weeks: [ShabbatWeek] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    /// Nil means "where I am now"; otherwise the saved place being shown.
    private(set) var savedPlace: SavedPlace?
    private let manager = CLLocationManager()
    private var activeFetchID = UUID()

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Shows a saved place, or the current location when `place` is nil.
    func show(place: SavedPlace?) {
        savedPlace = place
        if let place {
            Task { await load(latitude: place.latitude, longitude: place.longitude, zone: place.timeZoneIdentifier, name: place.name) }
        } else {
            requestLocation()
        }
    }

    func requestLocation() {
        if let place = savedPlace { show(place: place); return }
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
        guard savedPlace == nil else { return }
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
        guard savedPlace == nil else { return }
        guard let latest = locations.last, latest.horizontalAccuracy >= 0, latest.horizontalAccuracy < 20000 else {
            errorMessage = AppLanguage.text("Could not get a reliable location. Try again.")
            return
        }
        Task { await fetchTimes(for: latest) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard savedPlace == nil else { return }
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
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard activeFetchID == fetchID, savedPlace == nil else { return }
        let mark = placemarks?.first
        let name = [mark?.locality, mark?.administrativeArea].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        await load(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            zone: mark?.timeZone?.identifier ?? TimeZone.current.identifier,
            name: name.isEmpty ? nil : name
        )
    }

    private func load(latitude: Double, longitude: Double, zone: String, name: String?) async {
        let fetchID = UUID()
        activeFetchID = fetchID
        isLoading = true
        errorMessage = nil
        weeks = []
        placeName = name
        do {
            // Start from yesterday so the Shabbat that is under way right now is still listed.
            let start = Date.now.addingTimeInterval(-24 * 3600)
            let fetched = try await ShabbatTimesService.fetchWeeks(
                latitude: latitude,
                longitude: longitude,
                timeZoneIdentifier: zone,
                from: start,
                weeks: 27,
                language: AppLanguage.effectiveCode(for: AppLanguage.preference)
            ).filter { ($0.havdalah ?? $0.shabbatDay.addingTimeInterval(24 * 3600)) > .now }
            guard activeFetchID == fetchID else { return }
            weeks = fetched
            WidgetSync.updateLocation(
                latitude: latitude,
                longitude: longitude,
                timeZoneIdentifier: zone,
                placeName: name,
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
    @StateObject private var places = PlaceStore()
    @EnvironmentObject private var pro: ProStore
    @Environment(\.locale) private var locale
    @State private var showAddPlace = false
    @State private var showPaywall = false

    private var isAuthorized: Bool {
        model.authorization == .authorizedAlways || model.authorization == .authorizedWhenInUse
    }
    private var usesCurrentLocation: Bool { places.activePlace == nil }
    private var isHebrew: Bool { locale.identifier.hasPrefix("he") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    placeMenu
                    if usesCurrentLocation && !isAuthorized { permissionCard }
                    if model.isLoading {
                        ProgressView("Loading times for your location…").frame(maxWidth: .infinity).padding(.vertical, 30)
                    } else if model.weeks.isEmpty {
                        unavailableCard
                    } else {
                        if let first = model.weeks.first { hero(first) }
                        if model.weeks.count > 1 {
                            Text("Coming Shabbatot")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                .padding(.top, 6)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(model.weeks.dropFirst()) { week in upcomingRow(week) }
                        }
                    }
                    Text("Times by [Hebcal.com](https://www.hebcal.com), licensed CC BY 4.0. Your coordinates are sent to Hebcal to calculate them. Times are provided for convenience; customs differ, so confirm with your rabbi or local calendar.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Shabbat times")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Refresh times")
                }
            }
            .sheet(isPresented: $showAddPlace) { AddPlaceSheet(places: places) { place in select(place.id) } }
            .sheet(isPresented: $showPaywall) { PaywallView(reason: .places) }
            .task { model.show(place: places.activePlace) }
        }
    }

    // MARK: Place

    private var placeMenu: some View {
        Menu {
            Button {
                select(nil)
            } label: {
                Label("Current location", systemImage: usesCurrentLocation ? "checkmark" : "location")
            }
            ForEach(places.places) { place in
                Button {
                    select(place.id)
                } label: {
                    Label(place.name, systemImage: places.activeID == place.id ? "checkmark" : "mappin")
                }
            }
            Divider()
            Button { addPlaceTapped() } label: { Label("Add a place", systemImage: "plus") }
            if let active = places.activePlace {
                Button(role: .destructive) { places.remove(active.id); model.show(place: places.activePlace) } label: {
                    Label("Remove this place", systemImage: "trash")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: usesCurrentLocation ? "location.fill" : "mappin.circle.fill").foregroundStyle(.tint)
                Text(model.placeName ?? (usesCurrentLocation ? AppLanguage.text("Current location") : (places.activePlace?.name ?? "")))
                    .font(.headline)
                Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                ProBadge()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
        }
        .accessibilityLabel(Text("Choose a place"))
    }

    private func select(_ id: UUID?) {
        places.select(id)
        model.show(place: places.activePlace)
    }

    private func addPlaceTapped() {
        if ProPolicy.canSavePlace(currentCount: places.places.count, hasPro: pro.hasPro) {
            showAddPlace = true
        } else if !pro.hasPro {
            showPaywall = true
        }
    }

    // MARK: Cards

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Location permission is required", systemImage: "location.fill").font(.headline)
            Text("Shabbat times are calculated for your current location. Without location access, no times are shown.")
                .font(.footnote).foregroundStyle(.secondary)
            if model.authorization == .denied || model.authorization == .restricted {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            } else {
                Button { model.refresh() } label: { Label("Allow location", systemImage: "location.circle") }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var unavailableCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "sun.horizon").font(.system(size: 40)).foregroundStyle(.secondary).accessibilityHidden(true)
            Text("Times unavailable").font(.title3.bold())
            Text(model.errorMessage ?? AppLanguage.text("Allow location access to calculate times."))
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
    }

    private func title(for week: ShabbatWeek) -> String {
        let parasha = isHebrew ? (week.parashaHebrew ?? week.parashaEnglish) : (week.parashaEnglish ?? week.parashaHebrew)
        let holiday = isHebrew ? (week.holidayHebrew ?? week.holidayEnglish) : (week.holidayEnglish ?? week.holidayHebrew)
        return [parasha, holiday].compactMap { $0 }.joined(separator: " · ")
    }

    /// "in 4 days", or "In progress" while Shabbat or the holiday is under way.
    private func countdown(for week: ShabbatWeek) -> String? {
        if let candle = week.candleLighting, candle > .now {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = locale
            formatter.unitsStyle = .full
            return formatter.localizedString(for: candle, relativeTo: .now)
        }
        if let havdalah = week.havdalah, havdalah > .now { return AppLanguage.text("In progress") }
        return nil
    }

    private func hero(_ week: ShabbatWeek) -> some View {
        let heading = AppLanguage.text(week.parashaEnglish == nil && week.holidayEnglish != nil ? "Next holiday" : "This Shabbat")
        return VStack(alignment: .leading, spacing: 14) {
            Text(heading)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(.tint.opacity(0.16), in: Capsule())
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                if let countdown = countdown(for: week) {
                    Text(countdown).font(.system(size: 34, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                }
                let name = title(for: week)
                if !name.isEmpty { Text(name).font(.title3.weight(.semibold)) }
                Text(week.shabbatDay.formatted(in: locale, date: .complete)).font(.subheadline).foregroundStyle(.secondary)
                Text(week.shabbatDay.hebrewDateString(in: locale)).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                timeBlock("Candle lighting", symbol: "flame", date: week.candleLighting)
                timeBlock("Shabbat ends", symbol: "moon.stars", date: week.havdalah)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.accentColor.opacity(0.28), Color(uiColor: .secondarySystemGroupedBackground)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }

    private func timeBlock(_ label: LocalizedStringKey, symbol: String, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(date?.formatted(in: locale, time: .shortened) ?? "—")
                .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground).opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func upcomingRow(_ week: ShabbatWeek) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                let name = title(for: week)
                if !name.isEmpty { Text(name).font(.headline) }
                Text(week.shabbatDay.formatted(in: locale, date: .abbreviated)).font(.footnote).foregroundStyle(.secondary)
                Text(week.shabbatDay.hebrewDateString(in: locale)).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Label(week.candleLighting?.formatted(in: locale, time: .shortened) ?? "—", systemImage: "flame")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Label(week.havdalah?.formatted(in: locale, time: .shortened) ?? "—", systemImage: "moon.stars")
                    .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Search for a city and save it.
struct AddPlaceSheet: View {
    @ObservedObject var places: PlaceStore
    let onAdded: (SavedPlace) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PlaceSearch.Result] = []
    @State private var searching = false
    @State private var searched = false

    var body: some View {
        NavigationStack {
            List {
                if searching {
                    ProgressView().frame(maxWidth: .infinity)
                } else if results.isEmpty && searched {
                    Text("No places found.").foregroundStyle(.secondary)
                }
                ForEach(results) { result in
                    Button {
                        places.add(result.place)
                        let saved = places.places.first { abs($0.latitude - result.place.latitude) < 0.01 && abs($0.longitude - result.place.longitude) < 0.01 } ?? result.place
                        onAdded(saved)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title).font(.headline).foregroundStyle(.primary)
                            if !result.subtitle.isEmpty { Text(result.subtitle).font(.footnote).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("City or address"))
            .onSubmit(of: .search) { Task { await run() } }
            .navigationTitle("Add a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func run() async {
        searching = true
        results = await PlaceSearch.search(query)
        searching = false
        searched = true
    }
}
