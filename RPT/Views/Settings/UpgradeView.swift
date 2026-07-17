//
//  UpgradeView.swift
//  RPT
//

import SwiftUI

struct UpgradeView: View {
    @ObservedObject private var purchaseManager = StoreKitPurchaseManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                heroCard
                tierComparison
                faqCard
            }
            .padding(Theme.screenPadding)
        }
        .background(Theme.screenBackground)
        .navigationTitle("RPT Pro")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await purchaseManager.start()
        }
        .alert("RPT Pro", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseManager.alertMessage ?? "Please try again.")
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PillTag(text: MonetizationPlan.launchOfferTitle, tint: Theme.amber, icon: "bolt.fill")
                Spacer()
                Text(purchaseManager.displayPrice)
                    .font(Theme.statFont(size: 28))
                    .monospacedDigit()
                    .foregroundStyle(Theme.brandGradient)
            }

            Text("Train for free. Upgrade when you want deeper insight and more planning headroom.")
                .font(Theme.titleFont(size: 18))
                .foregroundStyle(Theme.textPrimary)

            Text(MonetizationPlan.upgradeCTA)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)

            Text(MonetizationPlan.launchOfferSummary)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

            VStack(spacing: 10) {
                Button {
                    Task {
                        await purchaseManager.purchasePro()
                    }
                } label: {
                    Label(purchaseManager.purchaseButtonTitle, systemImage: purchaseManager.isUnlocked ? "checkmark.seal.fill" : "crown.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BrandButtonStyle())
                .disabled(!purchaseManager.canPurchase)

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
            Text("What happens next?")
                .font(Theme.titleFont(size: 16))
                .foregroundStyle(Theme.textPrimary)

            Text("The current Linux runner can’t validate StoreKit transactions, restore purchases, or App Store product configuration. Those checks stay on the Verify-on-Mac queue before launch.")
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
                    PillTag(text: "Launch plan", tint: tint)
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
}
