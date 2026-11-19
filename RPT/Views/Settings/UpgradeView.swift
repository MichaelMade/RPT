//
//  UpgradeView.swift
//  RPT
//

import SwiftUI

struct UpgradeView: View {
    var source: FunnelSource = .settings
    var gateReason: FunnelGateReason? = nil

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchaseManager = StoreKitPurchaseManager.shared
    @State private var didTrackPaywallView = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                gateContextCard
                heroCard
                tierComparison
                faqCard
            }
            .padding(Theme.screenPadding)
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.screenBackground)
        .navigationTitle("RPT Pro")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            purchaseManager.paywallDidAppear()
            FunnelAnalytics.shared.rememberPaywallContext(
                source: source,
                gateReason: gateReason
            )
        }
        .onChange(of: purchaseManager.isUnlocked) { wasUnlocked, isUnlocked in
            // A gate sent the customer here and they have now unlocked Pro:
            // get out of the way so they land back on what they were doing.
            // Opened on its own (Settings, the Stats card), the screen stays
            // and shows the unlocked state.
            if gateReason != nil, !wasUnlocked, isUnlocked {
                dismiss()
            }
        }
        .task {
            await purchaseManager.start()
            guard !didTrackPaywallView else { return }
            didTrackPaywallView = true
            // An owner reopening this screen from Stats or Settings is not a
            // paywall exposure; counting it would dilute paid / paywall.
            guard !purchaseManager.isUnlocked else { return }
            FunnelAnalytics.shared.trackPaywallView(
                source: source,
                gateReason: gateReason,
                price: purchaseManager.displayPrice
            )
        }
        .alert("RPT Pro", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseManager.alertMessage ?? "Please try again.")
        }
    }

    /// Says why the paywall appeared when a Pro gate opened it.
    @ViewBuilder
    private var gateContextCard: some View {
        if let gateReason, !purchaseManager.isUnlocked {
            VStack(alignment: .leading, spacing: 6) {
                Label(MonetizationPlan.gateTitle(for: gateReason), systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(MonetizationPlan.gateMessage(for: gateReason))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rptCard()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("upgradeGateContext")
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PillTag(text: MonetizationPlan.purchaseOfferTitle, tint: Theme.amber, icon: "bolt.fill")
                Spacer()
                storePriceLabel
            }

            Text("Deeper progress. Unlimited templates. Yours for life.")
                .font(Theme.titleFont(size: 18))
                .foregroundStyle(Theme.textPrimary)

            Text("Keep logging free. Unlock RPT Pro when you want the full picture of your training.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)

            Text(MonetizationPlan.privacyNote)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.primary)

            VStack(spacing: 10) {
                Button {
                    Task {
                        if purchaseManager.state == .unavailable {
                            await purchaseManager.loadProducts()
                        } else {
                            await purchaseManager.purchasePro()
                        }
                    }
                } label: {
                    Label(purchaseManager.purchaseButtonTitle, systemImage: purchaseManager.isUnlocked ? "checkmark.seal.fill" : "crown.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BrandButtonStyle())
                .disabled(!purchaseManager.canActivatePurchaseButton)

                Button {
                    Task {
                        await purchaseManager.restorePurchases()
                    }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryCapsuleButtonStyle())
                .disabled(purchaseManager.state.isBusy)

                Text(purchaseManager.state.displayMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 4)
        }
        .rptCard()
    }

    private var tierComparison: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "What You Get")

            tierCard(for: MonetizationPlan.freeTier, tint: Theme.textTertiary)
            tierCard(for: MonetizationPlan.proTier, tint: Theme.amber)
        }
    }

    private var faqCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("One purchase. Yours for life.")
                .font(Theme.titleFont(size: 16))
                .foregroundStyle(Theme.textPrimary)

            Text("RPT Free keeps workout logging and core progress tools available without an account. Upgrade once to unlock Pro features across every device on your Apple ID.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)

            Text(MonetizationPlan.storeKitNote)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .rptCard()
    }

    private func tierCard(for tier: MonetizationTier, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tier.name)
                    .font(Theme.titleFont(size: 16))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if tier == MonetizationPlan.proTier {
                    PillTag(text: "Lifetime", tint: tint)
                }
            }

            Text(tier.summary)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)

            ForEach(tier.features, id: \.self) { feature in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tier == MonetizationPlan.proTier ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                        .padding(.top, 2)

                    Text(feature)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rptCard()
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { purchaseManager.alertMessage != nil },
            set: { if !$0 { purchaseManager.alertMessage = nil } }
        )
    }

    @ViewBuilder
    private var storePriceLabel: some View {
        if let displayPrice = purchaseManager.displayPrice {
            Text(displayPrice)
                .font(Theme.statFont(size: 28))
                .monospacedDigit()
                .foregroundStyle(Theme.brandGradient)
        } else {
            Text("One-time")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
