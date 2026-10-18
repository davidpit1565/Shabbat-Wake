import CoreLocation
import SwiftUI
import UIKit

/// Tracks the two permissions the app needs and asks for them in one place when the app opens.
@MainActor
final class PermissionGate: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var alarm: NativeAlarmKitService.AuthorizationState
    @Published private(set) var location: CLAuthorizationStatus
    @Published var isPresented = false
    private let manager = CLLocationManager()
    private var hasChecked = false

    override init() {
        alarm = .notDetermined
        location = manager.authorizationStatus
        super.init()
        manager.delegate = self
        Task { await refreshAlarm() }
    }

    var alarmAllowed: Bool { alarm == .authorized }
    var locationAllowed: Bool { location == .authorizedAlways || location == .authorizedWhenInUse }
    var allAllowed: Bool { alarmAllowed && locationAllowed }

    /// True when at least one permission can still be granted by asking (not yet answered).
    var canAsk: Bool { alarm == .notDetermined || location == .notDetermined }

    func refresh() {
        location = manager.authorizationStatus
        Task { await refreshAlarm() }
    }

    /// AlarmKit is asked off the main thread so a slow answer can never freeze the screen.
    private func refreshAlarm() async {
        alarm = await Task.detached(priority: .userInitiated) { NativeAlarmKitService.authorizationState() }.value
    }

    /// Called once when the app opens: shows the sheet if anything is missing.
    func checkOnLaunch() async {
        guard !hasChecked else { return }
        hasChecked = true
        location = manager.authorizationStatus
        await refreshAlarm()
        if !allAllowed { isPresented = true }
    }

    func allow() async {
        if alarm == .notDetermined {
            _ = try? await NativeAlarmKitService.requestAuthorization()
            await refreshAlarm()
        }
        if location == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        location = manager.authorizationStatus
        if allAllowed { isPresented = false }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refresh()
        if allAllowed { isPresented = false }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct PermissionsSheet: View {
    @ObservedObject var gate: PermissionGate

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
                .padding(.top, 28)
            Text("Allow what the app needs")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            VStack(spacing: 14) {
                row("alarm.fill", "Alarms", "So your wake-up alarms can ring.", allowed: gate.alarmAllowed)
                row("location.fill", "Location", "To calculate Shabbat times for where you are.", allowed: gate.locationAllowed)
            }
            .padding(.horizontal, 24)
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                if gate.canAsk {
                    Button {
                        Task { await gate.allow() }
                    } label: {
                        Text("Allow").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        gate.openSettings()
                    } label: {
                        Text("Open Settings").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("Not now") { gate.isPresented = false }
                    .padding(.vertical, 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func row(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey, allowed: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .frame(width: 34, height: 34)
                .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: allowed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(allowed ? Color.green : Color.secondary)
                .accessibilityLabel(allowed ? Text("Allowed") : Text("Not allowed"))
        }
    }
}
