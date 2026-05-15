//
//  ExerciseDetailView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData
import UIKit

struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise
    @StateObject private var templateViewModel = TemplateViewModel()
    @State private var showingEditSheet = false
    @State private var recentHistory: [(workout: Workout, set: ExerciseSet)] = []
    @State private var selectedSourceTemplate: WorkoutTemplate?
    @State private var copiedWorkoutName: String?
    @State private var showingCopySummaryAlert = false
    @State private var localActiveWorkout: Workout?
    @State private var showingLocalActiveWorkoutSheet = false
    @State private var templateStartFailureMessage: String?
    
    private let workoutManager = WorkoutManager.shared
    private let templateManager = TemplateManager.shared

    static func displayName(for exercise: Exercise) -> String {
        let collapsedName = exercise.name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return "Exercise"
        }

        return String(collapsedName.prefix(80))
    }

    static func normalizedInstructions(for exercise: Exercise) -> String? {
        let collapsedInstructions = exercise.instructions
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedInstructions.isEmpty else {
            return nil
        }

        return collapsedInstructions
    }

    static func recentHistoryEntries(from history: [(workout: Workout, sets: [ExerciseSet])]) -> [(workout: Workout, set: ExerciseSet)] {
        history
            .compactMap { workout, sets in
                let completedWorkingSets = sets.filter(\.isCompletedWorkingSet)

                guard let bestSet = completedWorkingSets.max(by: { lhs, rhs in
                    rhs.isBetterPerformance(than: lhs)
                }) else {
                    return nil
                }

                return (workout: workout, set: bestSet)
            }
            .sorted { lhs, rhs in
                if lhs.workout.date != rhs.workout.date {
                    return lhs.workout.date > rhs.workout.date
                }

                return lhs.set.completedAt > rhs.set.completedAt
            }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with icon
                HStack(alignment: .center, spacing: 16) {
                    // Exercise icon
                    ExerciseIconView(category: exercise.category, size: 60)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Self.displayName(for: exercise))
                            .font(.title2)
                            .fontWeight(.bold)

                        // Category and custom badge
                        HStack {
                            ExerciseCategoryTag(category: exercise.category)
                            
                            if exercise.isCustom {
                                Text("Custom")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                        
                        // Main muscles
                        if !exercise.primaryMuscleGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Primary Muscles")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    ForEach(exercise.primaryMuscleGroups, id: \.self) { muscle in
                                        MuscleGroupTag(muscleGroup: muscle, isPrimary: true)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Secondary muscles
                        if !exercise.secondaryMuscleGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Secondary Muscles")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    ForEach(exercise.secondaryMuscleGroups, id: \.self) { muscle in
                                        MuscleGroupTag(muscleGroup: muscle, isPrimary: false)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Instructions
                if let normalizedInstructions = Self.normalizedInstructions(for: exercise) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundColor(exercise.category.style.color)
                            
                            Text("Instructions")
                                .font(.headline)
                        }
                        
                        Text(normalizedInstructions)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // View progress charts
                NavigationLink(destination: ExerciseProgressView(exercise: exercise)) {
                    HStack {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundColor(.white)
                        Text("View Progress")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(exercise.category.style.color)
                    .cornerRadius(12)
                }

                // Recent history
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(exercise.category.style.color)

                        Text("Exercise History")
                            .font(.headline)
                    }
                    
                    if recentHistory.isEmpty {
                        Text("No workout history for this exercise")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(recentHistory.prefix(5).enumerated()), id: \.element.set.id) { _, entry in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(WorkoutDetailView.displayName(for: entry.workout))
                                            .font(.subheadline)

                                        Text(entry.workout.date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text(entry.set.formattedWeightReps)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }

                                VStack(spacing: 8) {
                                    HStack(spacing: 12) {
                                        NavigationLink(destination: WorkoutDetailView(workout: entry.workout)) {
                                            Label("Review Workout", systemImage: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.blue)

                                        if let sourceTemplate = sourceTemplate(for: entry.workout) {
                                            Button {
                                                selectedSourceTemplate = sourceTemplate
                                            } label: {
                                                Label("Open Template", systemImage: "square.on.square")
                                                    .font(.caption.weight(.semibold))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(.purple)
                                        }
                                    }

                                    Button {
                                        copyWorkoutSummary(entry.workout)
                                    } label: {
                                        Label("Copy Summary", systemImage: "doc.on.doc")
                                            .font(.caption.weight(.semibold))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.indigo)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.tertiarySystemBackground))
                            )
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(Self.displayName(for: exercise))
        .toolbar {
            if exercise.isCustom {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditExerciseView(exercise: exercise)
        }
        .navigationDestination(item: $selectedSourceTemplate) { template in
            TemplateDetailView(
                template: template,
                onStartWorkout: { openStartedWorkout($0) },
                onEditTemplate: nil,
                onDuplicateTemplate: nil,
                onResumeActiveWorkout: protectedResumableWorkout() == nil ? nil : {
                    guard let activeWorkout = protectedResumableWorkout() else { return }
                    openStartedWorkout(activeWorkout)
                },
                onSaveActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil ? nil : {
                    saveActiveWorkoutAndOpenTemplate(template)
                },
                onDiscardActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil ? nil : {
                    discardActiveWorkoutAndOpenTemplate(template)
                },
                activeWorkoutBlockMessage: sourceTemplateBlockMessage(for: template)
            )
        }
        .alert("Workout Summary Copied", isPresented: $showingCopySummaryAlert) {
            Button("OK", role: .cancel) {
                copiedWorkoutName = nil
            }
        } message: {
            Text(copySummaryMessage)
        }
        .alert("Workout Action Failed", isPresented: Binding(
            get: { templateStartFailureMessage != nil },
            set: { isPresented in
                if !isPresented {
                    templateStartFailureMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                templateStartFailureMessage = nil
            }
        } message: {
            Text(templateStartFailureMessage ?? "")
        }
        .sheet(isPresented: $showingLocalActiveWorkoutSheet, onDismiss: {
            if localActiveWorkout?.isCompleted == true {
                localActiveWorkout = nil
            }
        }) {
            if let localActiveWorkout {
                ActiveWorkoutView(workout: localActiveWorkout)
            }
        }
        .onAppear {
            loadRecentSets()
        }
    }
    
    // Load recent sets for this exercise
    private func loadRecentSets() {
        let history = workoutManager.getWorkoutHistory(for: exercise)
        recentHistory = Self.recentHistoryEntries(from: history)
    }

    private var copySummaryMessage: String {
        let workoutName = copiedWorkoutName ?? "Workout"
        return "Copied the summary for \(workoutName) so it’s ready to paste anywhere you need it."
    }

    private func sourceTemplate(for workout: Workout) -> WorkoutTemplate? {
        templateManager.sourceTemplate(for: workout)
    }

    private func protectedResumableWorkout() -> Workout? {
        WorkoutStateManager.shared.resolvedResumableWorkout(
            currentBinding: localActiveWorkout,
            fallbackWorkouts: workoutManager.getIncompleteWorkouts()
        )
    }

    private func sourceTemplateBlockMessage(for template: WorkoutTemplate) -> String? {
        guard let activeWorkout = protectedResumableWorkout() else {
            return nil
        }

        let activeWorkoutName = WorkoutRow.displayName(for: activeWorkout)
        let templateName = WorkoutTemplate.normalizedDisplayName(template.name)
        let templateSuffix = templateName == "Template"
            ? "before starting this template."
            : "before starting \(templateName)."

        return activeWorkoutName == "Workout"
            ? "You already have a workout in progress. Continue it \(templateSuffix)"
            : "You already have \(activeWorkoutName) in progress. Continue it \(templateSuffix)"
    }

    private func openStartedWorkout(_ startedWorkout: Workout) {
        localActiveWorkout = startedWorkout
        showingLocalActiveWorkoutSheet = true
    }

    private func saveActiveWorkoutAndOpenTemplate(_ template: WorkoutTemplate) {
        guard let activeWorkout = protectedResumableWorkout() else { return }

        switch templateViewModel.startTemplateAfterPersistingActiveWorkout(
            activeWorkout,
            action: .saveForLater,
            opening: template,
            persist: { workoutManager.saveWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            openStartedWorkout(startedWorkout)
        case .failure(let message):
            templateStartFailureMessage = message
        }
    }

    private func discardActiveWorkoutAndOpenTemplate(_ template: WorkoutTemplate) {
        guard let activeWorkout = protectedResumableWorkout() else { return }

        switch templateViewModel.startTemplateAfterPersistingActiveWorkout(
            activeWorkout,
            action: .discard,
            opening: template,
            persist: { workoutManager.deleteWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            openStartedWorkout(startedWorkout)
        case .failure(let message):
            templateStartFailureMessage = message
        }
    }

    private func copyWorkoutSummary(_ workout: Workout) {
        UIPasteboard.general.string = workout.generateFormattedSummary()
        copiedWorkoutName = WorkoutRow.displayName(for: workout)
        showingCopySummaryAlert = true
    }
}
