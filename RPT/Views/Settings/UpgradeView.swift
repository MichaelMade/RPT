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
                    .foregroundStyle(Theme.brandGradient)
            }

            Text("Train for free. Upgrade when you want deeper insight and more planning headroom.")
                .font(.title3.weight(.bold))

            Text(MonetizationPlan.upgradeCTA)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(MonetizationPlan.launchOfferSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 4)
        }
        .rptCard()
    }

    private var tierComparison: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "What You Get")

            tierCard(for: MonetizationPlan.freeTier, tint: .secondary)
            tierCard(for: MonetizationPlan.proTier, tint: Theme.amber)
        }
    }

    private var faqCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What happens next?")
                .font(.headline)

            Text("The current Linux runner can’t validate StoreKit transactions, restore purchases, or App Store product configuration. Those checks stay on the Verify-on-Mac queue before launch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(MonetizationPlan.storeKitNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .rptCard()
    }

    private func tierCard(for tier: MonetizationTier, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tier.name)
                    .font(.headline)

                Spacer()

                if tier == MonetizationPlan.proTier {
                    PillTag(text: "Launch plan", tint: tint)
                }
            }

            Text(tier.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(tier.features, id: \.self) { feature in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tier == MonetizationPlan.proTier ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(tint)
                        .padding(.top, 2)

                    Text(feature)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
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
