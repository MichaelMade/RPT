//
//  ExercisePickerView.swift
//  RPT
//
//  Shared exercise selector used when adding movements to a workout or
//  template. Tap a row to add it; create a custom exercise inline.
//  Also home of the monogram list language shared with the library.
//

import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExerciseLibraryViewModel()

    // Concrete PersistentIdentifier rather than the nested `Exercise.ID`
    // alias: resolution of the macro-generated alias has proven
    // order-sensitive across builds.
    var excludedExerciseIDs: Set<PersistentIdentifier> = []
    var title: String = "Add Exercise"
    let onSelect: (Exercise) -> Void

    @State private var showingCreateExercise = false

    private var selectableExercises: [Exercise] {
        viewModel.filteredExercises.filter { !excludedExerciseIDs.contains($0.id) }
    }

    var body: some View {
        let selectable = selectableExercises

        return NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.top, 12)

                categoryFilterBar(filteredCount: selectable.count)

                if selectable.isEmpty {
                    ScrollView {
                        EmptyStateCard(
                            icon: "magnifyingglass",
                            title: "No Matches",
                            message: viewModel.hasActiveFilters
                                ? viewModel.noMatchesDescription()
                                : "Every exercise is already in this workout.",
                            actionTitle: "Create Custom Exercise"
                        ) {
                            showingCreateExercise = true
                        }
                        .padding(.horizontal, Theme.screenPadding)
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    ScrollView {
                        ExerciseListCard(items: selectable) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                ExerciseListRow(exercise: exercise, accessory: .add)
                                    .accessibilityElement(children: .combine)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("exercise-picker-row")
                        }
                        .padding(.horizontal, Theme.screenPadding)
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .background(Theme.screenBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create custom exercise")
                }
            }
            .sheet(isPresented: $showingCreateExercise) {
                ExerciseFormView(mode: .create) {
                    viewModel.refreshExercises()
                }
            }
        }
    }

    // MARK: - Search & Filters

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            TextField("Search name, muscle, or \"push\"", text: $viewModel.searchText)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Search exercises")
                .accessibilityHint(ExerciseLibraryViewModel.searchPrompt)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(
            Theme.cardBackground,
            in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private func categoryFilterBar(filteredCount: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                let isAllSelected = viewModel.selectedCategory == nil
                FilterChip(
                    title: isAllSelected ? "All · \(filteredCount)" : "All",
                    isSelected: isAllSelected
                ) {
                    viewModel.selectedCategory = nil
                }

                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    let isSelected = viewModel.selectedCategory == category
                    FilterChip(
                        title: isSelected
                            ? "\(category.rawValue.capitalized) · \(filteredCount)"
                            : category.rawValue.capitalized,
                        isSelected: isSelected
                    ) {
                        viewModel.selectedCategory = isSelected ? nil : category
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Exercise List Row

struct ExerciseListRow: View {
    enum Accessory {
        case chevron
        case add
        case none
    }

    let exercise: Exercise
    var accessory: Accessory = .chevron

    var body: some View {
        HStack(spacing: 11) {
            ExerciseMonogramTile(name: exercise.displayName, isMuted: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if let caption = Self.caption(for: exercise) {
                    Text(caption)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            switch accessory {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityHidden(true)
            case .add:
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.primary)
                    .accessibilityHidden(true)
            case .none:
                EmptyView()
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .contentShape(Rectangle())
    }

    /// "Muscle · Category · Custom" caption, omitting parts that don't apply.
    static func caption(for exercise: Exercise) -> String? {
        var parts: [String] = []

        if let muscle = exercise.primaryMuscleGroups.first {
            parts.append(muscle.displayName)
        }

        parts.append(exercise.category.rawValue.capitalized)

        if exercise.isCustom {
            parts.append("Custom")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Monogram Tile

/// Deterministic initials + content-palette color for an exercise, so a
/// movement keeps the same monogram everywhere in the app.
enum ExerciseMonogram {
    static func initials(for name: String) -> String {
        let words = name
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "–" })
            .filter { !$0.isEmpty }

        guard let firstWord = words.first, let firstLetter = firstWord.first else {
            return "EX"
        }

        if words.count > 1, let lastLetter = words.last?.first {
            return String([firstLetter, lastLetter]).uppercased()
        }

        if let secondLetter = firstWord.dropFirst().first {
            return String([firstLetter, secondLetter]).uppercased()
        }

        return String(firstLetter).uppercased()
    }

    /// Stable tile palette. Uses a deterministic FNV-1a hash of the name so
    /// the color survives relaunches, unlike Swift's seeded `hashValue`.
    static func palette(for name: String) -> (background: Color, foreground: Color) {
        let palettes: [(background: Color, foreground: Color)] = [
            (Theme.primaryTint, Theme.primary),
            (Theme.purpleTint, Theme.purple),
            (Theme.orangeTint, Theme.dropOne),
        ]

        var hash: UInt32 = 2_166_136_261
        for scalar in name.unicodeScalars {
            hash = (hash ^ scalar.value) &* 16_777_619
        }

        return palettes[Int(hash % UInt32(palettes.count))]
    }
}

struct ExerciseMonogramTile: View {
    let name: String
    var isMuted: Bool = false
    var size: CGFloat = 34

    var body: some View {
        let colors = isMuted
            ? (background: Theme.surfaceMuted, foreground: Theme.textSecondary)
            : ExerciseMonogram.palette(for: name)

        Text(ExerciseMonogram.initials(for: name))
            .font(.system(size: max(11, size * 0.35), weight: .semibold))
            .foregroundStyle(colors.foreground)
            .frame(width: size, height: size)
            .background(
                colors.background,
                in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Bordered List Card

/// White bordered card that stacks rows with hairline separators — the
/// Vibe list container used by the exercise library and picker.
struct ExerciseListCard<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(items) { item in
                row(item)

                if item.id != items.last?.id {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
            }
        }
        .rptCard(padding: 0)
    }
}
