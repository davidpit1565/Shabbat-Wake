import SwiftUI

/// Why the paywall opened, so the first line speaks to what the person just tried to do.
enum PaywallReason {
    case moreReminders
    case reminderTime
    case icons
    case weeksAhead
    case general

    var headline: LocalizedStringKey {
        switch self {
        case .moreReminders: "More reminders are part of Pro"
        case .reminderTime: "Choosing the time is part of Pro"
        case .icons: "Extra icons are part of Pro"
        case .weeksAhead: "Limiting an alarm to some weeks is part of Pro"
        case .general: "Shabbat Waker Pro"
        }
    }
}

struct PaywallView: View {
    let reason: PaywallReason
    @EnvironmentObject private var pro: ProStore
    @Environment(\.dismiss) private var dismiss

    private let benefits: [(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey)] = [
        ("bell.badge", "Several reminders", "Remind yourself more than once before candle lighting."),
        ("clock", "Your own times", "Choose how many minutes before, for each reminder."),
        ("lock.rectangle", "Lock Screen widgets", "Candle lighting, Shabbat ends and your next alarm on the Lock Screen."),
        ("calendar.badge.clock", "Alarms for some weeks", "Set an alarm for the next 4, 8, 12 or 26 weeks, then it ends on its own."),
        ("app.badge", "All app icons", "Pick any of the extra icons.")
    ]

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
                        Text("One purchase, yours for good. No subscription, no account.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
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
                    Text("Always free: alarms that stop by themselves, Shabbat times, Home Screen widgets and one reminder before candle lighting.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if ProStore.isEnforced && !pro.hasPro {
                        Button {
                            Task { await pro.purchase() }
                        } label: {
                            Text(pro.lifetimeProduct.map { String(format: AppLanguage.text("Buy · %@"), $0.displayPrice) } ?? AppLanguage.text("Unlock Pro"))
                                .font(.headline)
                        }
                        .disabled(pro.isPurchasing || pro.lifetimeProduct == nil)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Shabbat Waker Pro", isPresented: Binding(get: { pro.message != nil }, set: { if !$0 { pro.message = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(pro.message ?? "")
            }
            .task { if pro.lifetimeProduct == nil { await pro.loadProduct() } }
        }
        .presentationDetents([.large])
    }

    /// One big action at the bottom, on a blurred bar, like the Habit Tracker app.
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
                    Task { await pro.purchase() }
                } label: {
                    Group {
                        if pro.isPurchasing {
                            ProgressView()
                        } else if let product = pro.lifetimeProduct {
                            Text("Unlock Pro · \(product.displayPrice)")
                        } else {
                            Text("Unlock Pro")
                        }
                    }
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(pro.isPurchasing || pro.lifetimeProduct == nil)
                if pro.productUnavailable {
                    Text("The purchase isn't available right now. Please try again later.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
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
            .foregroundStyle(Color.orange)
            .background(Color.orange.opacity(0.16), in: Capsule())
            .accessibilityLabel("Pro feature")
    }
}
