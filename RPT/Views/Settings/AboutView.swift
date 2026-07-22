//
//  AboutView.swift
//  RPT
//

import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                VStack(spacing: 12) {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 44))
                        .rotationEffect(.degrees(180))
                        .foregroundStyle(Theme.brandGradient)

                    Text("RPT")
                        .font(.largeTitle.weight(.heavy))

                    Text("Reverse Pyramid Training")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    PillTag(text: "Version \(appVersion)", tint: .secondary)
                }
                .frame(maxWidth: .infinity)
                .rptCard()

                VStack(alignment: .leading, spacing: 14) {
                    aboutRow(
                        icon: "arrow.down.right.circle.fill",
                        title: "Heaviest set first",
                        text: "Hit your top set while you're fresh, then drop the weight and add reps for each back-off set."
                    )
                    aboutRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Progress you can see",
                        text: "Estimated 1RM trends, weekly volume, muscle balance, and personal records — computed from every set you log."
                    )
                    aboutRow(
                        icon: "lock.fill",
                        title: "Private by design",
                        text: "Your training data stays on device. CSV export is user-initiated through the iOS share sheet when RPT Pro is unlocked."
                    )
                }
                .rptCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Support, Privacy & Terms")
                        .font(.headline)

                    linkRow(
                        icon: "questionmark.circle.fill",
                        title: "Get Support",
                        text: "Questions, bug reports, and launch feedback.",
                        url: AppStoreReleasePlan.supportURL
                    )

                    if let emailURL = URL(string: "mailto:moorem88@gmail.com?subject=RPT%20Support") {
                        linkRow(
                            icon: "envelope.fill",
                            title: "Email the Developer",
                            text: "Bugs and feature ideas go straight to the developer.",
                            url: emailURL,
                            accessibilityHint: "Opens your email app"
                        )
                    }

                    linkRow(
                        icon: "hand.raised.fill",
                        title: "Privacy Policy",
                        text: "Review RPT's no-account, on-device data policy.",
                        url: AppStoreReleasePlan.privacyURL
                    )

                    linkRow(
                        icon: "doc.text.fill",
                        title: "Terms of Use (EULA)",
                        text: "RPT uses Apple's standard terms for App Store purchases.",
                        url: AppStoreReleasePlan.standardEULAURL
                    )

                    Text("RPT has no accounts, analytics, ads, tracking SDKs, or developer-run workout-data servers. StoreKit handles RPT Pro purchases through Apple.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .rptCard()
            }
            .padding(Theme.screenPadding)
        }
        .background(Theme.screenBackground)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func aboutRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.brandGradient)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func linkRow(
        icon: String,
        title: String,
        text: String,
        url: URL,
        accessibilityHint: String = "Opens in Safari"
    ) -> some View {
        Link(destination: url) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.brandGradient)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(accessibilityHint)
    }
}
