import SwiftUI
import UIKit

enum AppIconOption: String, CaseIterable, Identifiable {
    case standard, classic, minimal, sunrise, timeLight, glass, premiumTech
    var id: String { rawValue }

    /// Name of the alternate icon set in the asset catalog; nil is the primary icon.
    var iconName: String? {
        switch self {
        case .standard: return nil
        case .classic: return "AppIconClassic"
        case .minimal: return "AppIconMinimal"
        case .sunrise: return "AppIconSunrise"
        case .timeLight: return "AppIconTimeLight"
        case .glass: return "AppIconGlass"
        case .premiumTech: return "AppIconPremiumTech"
        }
    }
    var previewImage: String {
        switch self {
        case .standard: return "IconPreviewDefault"
        case .classic: return "IconPreviewClassic"
        case .minimal: return "IconPreviewMinimal"
        case .sunrise: return "IconPreviewSunrise"
        case .timeLight: return "IconPreviewTimeLight"
        case .glass: return "IconPreviewGlass"
        case .premiumTech: return "IconPreviewPremiumTech"
        }
    }
    var title: LocalizedStringKey {
        switch self {
        case .standard: return "Default"
        case .classic: return "Classic"
        case .minimal: return "Minimal"
        case .sunrise: return "Sunrise"
        case .timeLight: return "Time & Light"
        case .glass: return "Glass"
        case .premiumTech: return "Premium Tech"
        }
    }
    var requiresPro: Bool { self != .standard }

    static func current() -> AppIconOption {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.iconName == name } ?? .standard
    }
}

struct AppIconPickerScreen: View {
    @EnvironmentObject private var pro: ProStore
    @State private var selected = AppIconOption.current()
    @State private var errorMessage: String?
    @State private var showPaywall = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(AppIconOption.allCases) { option in
                    Button { choose(option) } label: { cell(option) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        .accessibilityValue(option.requiresPro && !pro.hasPro ? Text("Pro feature") : Text(""))
                        .accessibilityAddTraits(option == selected ? .isSelected : [])
                }
            }
            .padding(16)
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red).padding(.horizontal, 20)
            }
        }
        .navigationTitle("App icon")
        .onAppear { selected = AppIconOption.current() }
        .sheet(isPresented: $showPaywall) { PaywallView(reason: .icons) }
    }

    private func cell(_ option: AppIconOption) -> some View {
        let unlocked = !option.requiresPro || pro.hasPro
        return VStack(spacing: 8) {
            Image(option.previewImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(option == selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: option == selected ? 3 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.bold))
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(6)
                    }
                }
            Text(option.title).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func choose(_ option: AppIconOption) {
        guard !option.requiresPro || pro.hasPro else { showPaywall = true; return }
        errorMessage = nil
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(option.iconName)
                selected = option
            } catch {
                errorMessage = AppLanguage.text("The icon could not be changed.")
            }
        }
    }
}
