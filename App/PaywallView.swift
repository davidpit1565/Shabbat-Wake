import StoreKit
import SwiftUI

/// Why the paywall opened, so the first line speaks to what the person just tried to do.
enum PaywallReason {
    case moreReminders
    case reminderTime
    case icons
    case weeksAhead
    case places
    case general

    var headline: LocalizedStringKey {
        switch self {
        case .moreReminders: "More reminders are part of Pro"
        case .reminderTime: "Choosing the time is part of Pro"
        case .icons: "Extra icons are part of Pro"
        case .weeksAhead: "Limiting an alarm to some weeks is part of Pro"
        case .places: "Saved places are part of Pro"
        case .general: "Shabbat Waker Pro"
        }
    }
}

struct PaywallView: View {
    let reason: PaywallReason
    @EnvironmentObject private var pro: ProStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = ProStore.yearlyProductID

    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL = URL(string: "https://davidpit1565.github.io/Shabbat-Wake/privacy/")!

    private let benefits: [(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey)] = [
        ("mappin.and.ellipse", "Saved places", "Keep times for home, family and trips, and switch between them."),
        ("bell.badge", "Several reminders", "Remind yourself more than once before candle lighting, at times you choose."),
        ("calendar.badge.clock", "Alarms for some weeks", "Set an alarm for the next 4, 8, 12 or 26 weeks, then it ends on its own."),
        ("app.badge", "All app icons", "Pick any of the extra icons.")
    ]

    private var selected: Product? { pro.products.first { $0.id == selectedID } ?? pro.products.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.tint)
                        .frame(width: 64, height: 64)
                        .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reason.headline)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Cancel any time. No account.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Included in Pro")
                        .font(.title3.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<benefits.count, id: \.self) { index in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: benefits[index].symbol)
                                    .font(.title3).foregroundStyle(.tint).frame(width: 30)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(benefits[index].title).font(.headline)
                                    Text(benefits[index].detail).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(16)
                            .accessibilityElement(children: .combine)
                            if index < benefits.count - 1 { Divider().padding(.leading, 60) }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    if ProStore.isEnforced && !pro.hasPro { plans }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Free for everyone")
                            .font(.title3.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Text("Always free: unlimited alarms, Shabbat times, Siri, Apple Watch, all widgets and one reminder before candle lighting.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if ProStore.isEnforced { legal }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if ProStore.isEnforced && !pro.hasPro, let product = selected {
                        Button {
                            Task { await pro.purchase(product) }
                        } label: {
                            Text(String(format: AppLanguage.text("Subscribe · %@"), product.displayPrice)).font(.headline)
                        }
                        .disabled(pro.isPurchasing)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Shabbat Waker Pro", isPresented: Binding(get: { pro.message != nil }, set: { if !$0 { pro.message = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(pro.message ?? "")
            }
            .task { if pro.products.isEmpty { await pro.loadProducts() } }
        }
        .presentationDetents([.large])
    }

    /// Yearly and monthly side by side; yearly is chosen first.
    private var plans: some View {
        VStack(spacing: 10) {
            if pro.products.isEmpty {
                Text(pro.productsUnavailable ? "The purchase isn't available right now. Please try again later." : " ")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(pro.products, id: \.id) { product in
                planCard(product)
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isYearly = product.id == ProStore.yearlyProductID
        let isSelected = (selected?.id == product.id)
        return Button {
            selectedID = product.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "Yearly" : "Monthly").font(.headline)
                        if isYearly, let percent = pro.yearlySavingsPercent {
                            Text(String(format: AppLanguage.text("Save %d%%"), percent))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .foregroundStyle(Color.green)
                                .background(Color.green.opacity(0.16), in: Capsule())
                        }
                    }
                    if isYearly {
                        Text(String(format: AppLanguage.text("%@ a month, billed yearly"), (product.price / 12).formatted(product.priceFormatStyle)))
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("Billed monthly").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Text(isYearly ? String(format: AppLanguage.text("%@ / year"), product.displayPrice) : String(format: AppLanguage.text("%@ / month"), product.displayPrice))
                    .font(.subheadline.weight(.semibold))
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// What Apple requires next to a subscription offer.
    private var legal: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment is charged to your Apple ID when you confirm. The subscription renews automatically unless it is cancelled at least 24 hours before the end of the current period. Manage or cancel it in your Apple ID settings under Subscriptions.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Link("Terms of Use", destination: Self.termsURL)
                Link("Privacy Policy", destination: Self.privacyURL)
            }
            .font(.caption.weight(.semibold))
        }
    }

    /// One big action at the bottom, on a blurred bar.
    private var bottomBar: some View {
        VStack(spacing: 8) {
            if !ProStore.isEnforced {
                Label("Preview: everything is unlocked for now.", systemImage: "lock.open")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            } else if pro.hasPro {
                Label("You have Pro. Thank you!", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(Color.green)
            } else {
                Button {
                    if let product = selected { Task { await pro.purchase(product) } }
                } label: {
                    Group {
                        if pro.isPurchasing {
                            ProgressView()
                        } else if let product = selected {
                            Text(String(format: AppLanguage.text("Subscribe · %@"), product.displayPrice))
                        } else {
                            Text("Subscribe")
                        }
                    }
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(pro.isPurchasing || selected == nil)
                Button("Restore purchases") { Task { await pro.restore() } }
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}

/// A small "PRO" tag shown next to features that need Pro.
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .foregroundStyle(Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .systemOrange : UIColor(red: 0.62, green: 0.30, blue: 0, alpha: 1) }))
            .background(Color.orange.opacity(0.16), in: Capsule())
            .accessibilityLabel("Pro feature")
    }
}
