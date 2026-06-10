//
//  Theme.swift
//  RPT
//
//  The single source of truth for RPT's visual identity.
//  Brand palette is derived from the app icon: deep charcoal base with
//  a red-to-orange "heavy to light" gradient that mirrors a reverse
//  pyramid set scheme.
//

import SwiftUI
import UIKit

enum Theme {
    // MARK: - Brand Colors

    /// Primary brand orange (light back-off sets).
    static let accent = Color(red: 1.0, green: 0.478, blue: 0.2)

    /// Deep brand red (the heavy top set).
    static let accentDeep = Color(red: 0.84, green: 0.21, blue: 0.16)

    /// Warm amber used for streaks and highlights.
    static let amber = Color(red: 0.98, green: 0.66, blue: 0.2)

    /// Positive/confirmation green.
    static let success = Color(red: 0.22, green: 0.72, blue: 0.45)

    /// Informational blue used sparingly for secondary data.
    static let info = Color(red: 0.29, green: 0.56, blue: 0.93)

    // MARK: - Gradients

    static let brandGradient = LinearGradient(
        colors: [accentDeep, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subtleBrandGradient = LinearGradient(
        colors: [accentDeep.opacity(0.18), accent.opacity(0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Surfaces

    static var cardBackground: Color {
        Color(UIColor.secondarySystemGroupedBackground)
    }

    static var screenBackground: Color {
        Color(UIColor.systemGroupedBackground)
    }

    // MARK: - Metrics

    static let cardCornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let screenPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 20

    // MARK: - Typography helpers

    /// Big rounded numerals for stats and timers.
    static func statFont(size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

// MARK: - Card Styling

struct CardBackgroundModifier: ViewModifier {
    var padding: CGFloat = Theme.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                Theme.cardBackground,
                in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
            )
    }
}

extension View {
    /// Wraps the view in RPT's standard rounded card.
    func rptCard(padding: CGFloat = Theme.cardPadding) -> some View {
        modifier(CardBackgroundModifier(padding: padding))
    }
}

// MARK: - Button Styles

/// Prominent gradient capsule used for the single most important action on a screen.
struct BrandButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Theme.brandGradient, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Quiet capsule for secondary actions.
struct SecondaryCapsuleButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(tint.opacity(0.12), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
