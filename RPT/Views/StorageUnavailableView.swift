//
//  StorageUnavailableView.swift
//  RPT
//
//  Blocking recovery screen shown when the on-device SwiftData store cannot
//  be opened. Normal app content stays inaccessible so temporary writes can
//  never be mistaken for saved workout history.
//

import SwiftUI

struct StorageUnavailableView: View {
    var body: some View {
        ZStack {
            Theme.screenBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 46, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.primary)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text("Storage Unavailable")
                            .font(Theme.titleFont(size: 26))
                            .foregroundStyle(Theme.textPrimary)

                        Text("RPT couldn't open your training data, so workout editing is temporarily disabled.")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)

                        Text("Your existing data has not been deleted or replaced. Close RPT and try again. If this continues, contact support before deleting or reinstalling the app.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Link(destination: AppStoreReleasePlan.supportURL) {
                        Label("Contact Support", systemImage: "questionmark.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Theme.primaryAction,
                                in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                            )
                    }
                    .accessibilityHint("Opens RPT support information")
                }
                .padding(28)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    StorageUnavailableView()
}
