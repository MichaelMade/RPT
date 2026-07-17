//
//  Theme.swift
//  RPT
//
//  The single source of truth for RPT's visual identity.
//
//  Vibe design language: calm white-on-gray chrome with hairline borders,
//  a single blue action color, and the content palette doing the data
//  storytelling — the reverse-pyramid ladder reads top set (red) →
//  −10% (orange) → −15% (amber), with done-green for logged work.
//

import SwiftUI
import UIKit

enum Theme {
    // MARK: - Chrome (adaptive light/dark)

    /// App canvas behind cards — riverstone gray.
    static let screenBackground = adaptive(light: 0xF6F7FB, dark: 0x191A1F)

    /// Card / elevated surface.
    static let cardBackground = adaptive(light: 0xFFFFFF, dark: 0x23242B)

    /// 1px card and chrome borders.
    static let border = adaptive(light: 0xD0D4E4, dark: 0x3C3E4A)

    /// Hairline row separators inside cards.
    static let hairline = adaptive(light: 0xECEFF8, dark: 0x2D2F38)

    /// Muted fill for chips, empty day tiles, unselected controls.
    static let surfaceMuted = adaptive(light: 0xECEFF8, dark: 0x2D2F38)

    /// Primary text — mud black.
    static let textPrimary = adaptive(light: 0x323338, dark: 0xE6E7EB)

    /// Secondary text — asphalt.
    static let textSecondary = adaptive(light: 0x676879, dark: 0x9A9CAA)

    /// Disabled / placeholder values.
    static let textTertiary = adaptive(light: 0xC3C6D4, dark: 0x565866)

    /// Dark inverted surface (docked rest timer bar).
    static let inverted = adaptive(light: 0x323338, dark: 0x101116)

    // MARK: - Action color

    /// Vibe blue — the one action color.
    static let primary = adaptive(light: 0x0073EA, dark: 0x2E8AF6)

    /// Light blue selection tint (active set row, icon tiles).
    static let primaryTint = adaptive(light: 0xE5F4FF, dark: 0x12283F)

    // MARK: - Content palette (same in both modes — data does the talking)

    /// The heavy top set.
    static let topSet = Color(hex: 0xDF2F4A)

    /// First back-off (−10%).
    static let dropOne = Color(hex: 0xFF6D3B)

    /// Second back-off (−15%).
    static let dropTwo = Color(hex: 0xFDAB3D)

    /// Logged / done green.
    static let done = Color(hex: 0x00C875)

    /// Template & data accent purple.
    static let purple = Color(hex: 0xA25DDC)

    /// Tints behind content-colored icons and banners.
    static let orangeTint = adaptive(light: 0xFFF0E6, dark: 0x3A2417)
    static let purpleTint = adaptive(light: 0xF3EBFA, dark: 0x2E2138)
    static let amberTint = adaptive(light: 0xFFF8E6, dark: 0x3A3113)

    // MARK: - Charts

    /// Consistency heatmap ramp, empty → most volume.
    static let heatRamp: [Color] = [
        surfaceMuted,
        Color(hex: 0x79AFF1),
        Color(hex: 0x3D92F5),
        Color(hex: 0x0073EA),
        Color(hex: 0x00418F),
    ]

    /// Volume bars: past weeks dim, recent mid, current week `primary`.
    static let chartBarDim = adaptive(light: 0xA9C9F0, dark: 0x2B4C74)
    static let chartBarMid = adaptive(light: 0x7FB0EC, dark: 0x3A6398)

    // MARK: - Legacy aliases (older call sites; keep values on-palette)

    static let accent = dropOne
    static let accentDeep = topSet
    static let amber = dropTwo
    static let success = done
    static let info = primary

    // MARK: - Gradients

    /// Blue gradient reserved for the Pro banner.
    static let proGradient = LinearGradient(
        colors: [Color(hex: 0x00418F), Color(hex: 0x0073EA)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0x3D92F5), Color(hex: 0x0073EA)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subtleBrandGradient = LinearGradient(
        colors: [Color(hex: 0x0073EA).opacity(0.14), Color(hex: 0x3D92F5).opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Metrics

    static let cardCornerRadius: CGFloat = 12
    static let smallCornerRadius: CGFloat = 8
    static let chipCornerRadius: CGFloat = 6
    static let cardPadding: CGFloat = 14
    static let screenPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 12

    // MARK: - Typography helpers

    /// Titles and big numerals (Poppins in the design; SF semibold here).
    static func titleFont(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    /// Big numerals for stats and timers — always tabular.
    static func statFont(size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Uppercase letterspaced section eyebrow ("THIS WEEK", "TRAINING").
    static func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(textSecondary)
    }

    // MARK: - Helpers

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
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
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

extension View {
    /// Wraps the view in RPT's standard bordered card.
    func rptCard(padding: CGFloat = Theme.cardPadding) -> some View {
        modifier(CardBackgroundModifier(padding: padding))
    }
}

// MARK: - Button Styles

/// Solid Vibe-blue button for the single most important action on a screen.
struct BrandButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                Theme.primary,
                in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet bordered button for secondary actions.
struct SecondaryCapsuleButtonStyle: ButtonStyle {
    var tint: Color = Theme.textPrimary
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                Theme.cardBackground,
                in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
