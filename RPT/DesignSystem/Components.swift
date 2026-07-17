//
//  Components.swift
//  RPT
//
//  Small reusable building blocks shared across every screen so the app
//  has one consistent visual language.
//

import SwiftUI

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.titleFont(size: 16))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
    }
}

// MARK: - Stat Tile

struct StatTile: View {
    let title: String
    let value: String
    var caption: String? = nil
    var icon: String? = nil
    var tint: Color = Theme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(Theme.statFont(size: 22))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let caption {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rptCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pill Tag

struct PillTag: View {
    let text: String
    var tint: Color = Theme.textSecondary
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            tint.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
        .foregroundStyle(tint)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isSelected ? Theme.primary : Theme.cardBackground,
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Theme.border,
                        lineWidth: 1
                    )
                )
                .foregroundStyle(isSelected ? .white : Theme.textPrimary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Theme.primary)

            Text(title)
                .font(Theme.titleFont(size: 16))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryCapsuleButtonStyle(tint: Theme.primary))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .rptCard()
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    /// 0...1
    let progress: Double
    var lineWidth: CGFloat = 8
    var tint: AnyShapeStyle = AnyShapeStyle(Theme.primary)

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceMuted, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
        }
        // Decorative — hosts overlay the meaningful numbers as text.
        .accessibilityHidden(true)
    }
}

// MARK: - Labeled Value Row

struct LabeledValueRow: View {
    let label: String
    let value: String
    var valueTint: Color = Theme.textPrimary

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(valueTint)
        }
        .font(.system(size: 14))
    }
}

// MARK: - Stepper Control

/// Compact value stepper used for weight/reps adjustment in the workout logger.
struct ValueStepperControl: View {
    let value: String
    let unit: String?
    /// Spoken name for the value being adjusted (e.g. "weight"); falls back to the unit.
    var accessibilityName: String? = nil
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    private var spokenName: String {
        accessibilityName ?? unit ?? "value"
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.primary)
            .accessibilityLabel("Decrease \(spokenName)")
            .accessibilityValue(value)

            VStack(spacing: 0) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(minWidth: 44)
            .accessibilityElement(children: .combine)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.primary)
            .accessibilityLabel("Increase \(spokenName)")
            .accessibilityValue(value)
        }
        .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
    }
}

// MARK: - Template Key Color

/// Stable template → content-palette color mapping shared by workout rows
/// and template cards. Hashes the template id deterministically (Swift's
/// `hashValue` is randomized per launch) so a template keeps its color
/// across launches. Done-green stays out of the palette — it is reserved
/// for logged work and PR text rendered next to these key bars.
enum TemplateKeyColor {
    static let palette: [Color] = [
        Theme.primary,
        Theme.purple,
        Theme.dropTwo,
        Theme.dropOne,
    ]

    static func color(forKey key: String) -> Color {
        var hash: UInt64 = 5381
        for byte in key.utf8 {
            hash = hash &* 31 &+ UInt64(byte)
        }
        return palette[Int(hash % UInt64(palette.count))]
    }

    static func color(for workout: Workout) -> Color {
        let key = workout.startedFromTemplateID
            ?? workout.startedFromTemplate
            ?? workout.name
        return color(forKey: key)
    }
}
