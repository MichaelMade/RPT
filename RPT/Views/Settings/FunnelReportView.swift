//
//  FunnelReportView.swift
//  RPT
//
//  On-device 7-day and 30-day conversion funnel counts. Nothing here
//  leaves the device.
//

import SwiftUI

struct FunnelReportView: View {
    @State private var report = FunnelAnalytics.shared.report()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                introCard
                windowCard(title: "Last 7 days", counts: report.last7)
                windowCard(title: "Last 30 days", counts: report.last30)
            }
            .padding(Theme.screenPadding)
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.screenBackground)
        .navigationTitle("On-device funnel")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            report = FunnelAnalytics.shared.report()
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Counts on this device")
                .font(Theme.titleFont(size: 16))
                .foregroundStyle(Theme.textPrimary)

            Text("Anonymous install → paywall → purchase events stay in local storage. No name, Apple ID, IDFA, or workout data is attached.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)

            Text(remoteStatusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rptCard()
    }

    private var remoteStatusText: String {
        if FunnelAnalytics.shared.isRemoteConfigured {
            return "A remote app ID is present, but no analytics SDK is linked yet, so nothing is uploaded."
        }
        return "Remote analytics is off. No TelemetryDeck app ID is configured."
    }

    private func windowCard(title: String, counts: FunnelCounts) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.titleFont(size: 16))
                .foregroundStyle(Theme.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(FunnelEventName.allCases.enumerated()), id: \.element) { index, name in
                    countRow(label: Self.displayName(for: name), value: counts.count(for: name))
                    if index < FunnelEventName.allCases.count - 1 {
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(height: 1)
                    }
                }
            }

            Text(conversionLine(for: counts))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rptCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(accessibilitySummary(for: counts))")
    }

    private func countRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(value)")
                .font(Theme.statFont(size: 18))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 8)
    }

    private func conversionLine(for counts: FunnelCounts) -> String {
        guard let rate = counts.purchaseSuccessPerPaywall else {
            return "Paid / paywall: — (no paywall views)"
        }
        return "Paid / paywall: \(Self.percentFormatter.string(from: NSNumber(value: rate)) ?? "—")"
    }

    private func accessibilitySummary(for counts: FunnelCounts) -> String {
        FunnelEventName.allCases
            .map { "\(Self.displayName(for: $0)) \(counts.count(for: $0))" }
            .joined(separator: ", ")
    }

    private static func displayName(for name: FunnelEventName) -> String {
        switch name {
        case .install:
            return "Install"
        case .onboardingComplete:
            return "Onboarding complete"
        case .paywallView:
            return "Paywall view"
        case .purchaseStart:
            return "Purchase start"
        case .purchaseSuccess:
            return "Purchase success"
        case .purchaseFail:
            return "Purchase fail"
        case .restore:
            return "Restore"
        }
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
