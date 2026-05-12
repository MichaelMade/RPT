//
//  TemplatesListView.swift - Active Workout Sheet Approach
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct TemplatesListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TemplateViewModel()
    @State private var showingCreateSheet = false
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var currentAction: TemplateAction?
    @State private var showingConfirmationDialog = false
    @State private var templateToDelete: WorkoutTemplate?
    @State private var deleteResult: TemplateManager.DeletionResult?
    @State private var templateStartFailureMessage: String?
    @State private var searchText = ""
    @State private var createTemplatePrefillName = ""
    @State private var createTemplatePrefillNotes = ""
    @State private var createTemplatePrefillExercises: [TemplateExercise] = []
    @State private var quickStartTemplate: WorkoutTemplate?
    @State private var quickStartConfirmationMessage: String?
    
    private let templateManager = TemplateManager.shared
    
    // Bindings for active workout
    @Binding var activeWorkoutBinding: Workout?
    @Binding var showActiveWorkoutSheet: Bool
    
    // Default initializer with empty bindings for previews
    init() {
        self._activeWorkoutBinding = .constant(nil)
        self._showActiveWorkoutSheet = .constant(false)
    }
    
    // Custom initializer with bindings
    init(activeWorkoutBinding: Binding<Workout?>, showActiveWorkoutSheet: Binding<Bool>) {
        self._activeWorkoutBinding = activeWorkoutBinding
        self._showActiveWorkoutSheet = showActiveWorkoutSheet
    }
    
    enum TemplateAction {
        case detail
        case edit
    }

    private func prepareNewTemplateDraft(name: String = "", notes: String = "", exercises: [TemplateExercise] = []) {
        createTemplatePrefillName = name
        createTemplatePrefillNotes = notes
        createTemplatePrefillExercises = exercises.map { exercise in
            TemplateExercise(
                exerciseName: exercise.exerciseName,
                suggestedSets: exercise.suggestedSets,
                repRanges: exercise.repRanges,
                notes: exercise.notes
            )
        }
    }

    private func startDuplicating(_ template: WorkoutTemplate) {
        prepareNewTemplateDraft(
            name: viewModel.preferredDuplicateTemplateName(for: template),
            notes: template.notes,
            exercises: template.exercises
        )
        showingCreateSheet = true
    }
    
    var body: some View {
        NavigationStack {
            List {
                let activeWorkoutBlocksTemplateStart = protectedResumableWorkout() != nil
                let filteredTemplates = viewModel.fetchTemplates(blockedByActiveWorkout: activeWorkoutBlocksTemplateStart)

                if let summary = viewModel.filteredResultsSummary(filteredCount: filteredTemplates.count) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }

                if filteredTemplates.isEmpty {
                    let createRecoveryTitle = viewModel.createTemplateRecoveryTitle(filteredCount: filteredTemplates.count)

                    ContentUnavailableView {
                        Label(
                            viewModel.hasActiveSearch ? "No Matching Templates" : "No Templates Yet",
                            systemImage: viewModel.hasActiveSearch ? "magnifyingglass" : "list.bullet.clipboard"
                        )
                    } description: {
                        Text(viewModel.emptyStateDescription(filteredCount: filteredTemplates.count))
                    } actions: {
                        if let createRecoveryTitle {
                            Button(createRecoveryTitle) {
                                prepareNewTemplateDraft(
                                    name: viewModel.suggestedTemplateNameForEmptySearch(filteredCount: filteredTemplates.count) ?? ""
                                )
                                showingCreateSheet = true
                            }
                        }

                        if viewModel.hasActiveSearch {
                            Button("Clear Search") {
                                searchText = ""
                                viewModel.clearSearch()
                            }
                        } else {
                            Button("Create Template") {
                                prepareNewTemplateDraft(name: viewModel.preferredNewTemplatePrefillName())
                                showingCreateSheet = true
                            }
                        }
                    }
                } else {
                    ForEach(filteredTemplates) { template in
                        Button(action: {
                            selectedTemplate = template
                            currentAction = .detail
                        }) {
                            let templateCannotStartOnItsOwn = templateManager.startWorkoutDisabledMessage(for: template) != nil
                            let isBlockedByActiveWorkout = activeWorkoutBlocksTemplateStart && !templateCannotStartOnItsOwn
                            let statusTone = templateManager.templateStatusTone(for: template, blockedByActiveWorkout: isBlockedByActiveWorkout)
                            let statusTitle = templateManager.startWorkoutActionTitle(for: template, blockedByActiveWorkout: isBlockedByActiveWorkout)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(WorkoutTemplate.normalizedDisplayName(template.name))
                                        .font(.headline)

                                    Spacer(minLength: 8)

                                    Text(statusTitle)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(statusBadgeForegroundColor(for: statusTone))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(statusBadgeBackgroundColor(for: statusTone))
                                        .clipShape(Capsule())
                                        .multilineTextAlignment(.trailing)
                                }

                                HStack {
                                    Text(templateManager.templateListExerciseSummary(for: template, blockedByActiveWorkout: isBlockedByActiveWorkout))
                                        .font(.caption)
                                        .foregroundColor(summaryColor(for: statusTone))

                                    Spacer()

                                    // Preview of first few exercises
                                    if !template.exercises.isEmpty {
                                        let previewExerciseNames = templateManager.templateListPreviewExerciseNames(for: template)
                                        let hasMoreUniquePreviewExercises = templateManager.templateListHasMoreUniqueExercisesToPreview(for: template)
                                        Text(previewExerciseNames.joined(separator: ", ") +
                                             (hasMoreUniquePreviewExercises ? "..." : ""))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions {
                            Button {
                                selectedTemplate = template
                                currentAction = .edit
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)

                            Button {
                                startDuplicating(template)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            .tint(.indigo)

                            Button(role: .destructive) {
                                templateToDelete = template
                                showingConfirmationDialog = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    if viewModel.hasActiveSearch,
                       filteredTemplates.count == 1,
                       let matchedTemplate = filteredTemplates.first {
                        Section("Quick Actions") {
                            if !activeWorkoutBlocksTemplateStart,
                               templateManager.canStartWorkout(for: matchedTemplate) {
                                Button(templateManager.startWorkoutActionTitle(for: matchedTemplate)) {
                                    beginQuickStart(for: matchedTemplate)
                                }
                            } else if protectedResumableWorkout() != nil {
                                Button("Resume Current Workout") {
                                    showActiveWorkoutSheet = true
                                }
                            }

                            Button("Review \"\(WorkoutTemplate.normalizedDisplayName(matchedTemplate.name))\"") {
                                selectedTemplate = matchedTemplate
                                currentAction = .detail
                            }

                            Button("Edit \"\(WorkoutTemplate.normalizedDisplayName(matchedTemplate.name))\"") {
                                selectedTemplate = matchedTemplate
                                currentAction = .edit
                            }

                            Button("Duplicate \"\(WorkoutTemplate.normalizedDisplayName(matchedTemplate.name))\"") {
                                startDuplicating(matchedTemplate)
                            }

                            Button(role: .destructive) {
                                templateToDelete = matchedTemplate
                                showingConfirmationDialog = true
                            } label: {
                                Label(
                                    "Delete \"\(WorkoutTemplate.normalizedDisplayName(matchedTemplate.name))\"",
                                    systemImage: "trash"
                                )
                            }
                        }
                    }

                    if viewModel.shouldShowCreateTemplateFromSearchAction(filteredCount: filteredTemplates.count),
                       let createRecoveryTitle = viewModel.createTemplateRecoveryTitle(filteredCount: filteredTemplates.count) {
                        Button(createRecoveryTitle) {
                            prepareNewTemplateDraft(name: viewModel.suggestedTemplateNameFromSearch() ?? "")
                            showingCreateSheet = true
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }

                    if viewModel.shouldShowResultsRecoveryActions(filteredCount: filteredTemplates.count) {
                        Button("Clear Search") {
                            searchText = ""
                            viewModel.clearSearch()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search templates")
            .onChange(of: searchText) { _, newValue in
                viewModel.searchText = newValue
            }
            .navigationTitle("Workout Templates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        prepareNewTemplateDraft(name: viewModel.preferredNewTemplatePrefillName())
                        showingCreateSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet, onDismiss: {
                viewModel.refreshTemplates() // Refresh on dismiss
            }) {
                TemplateEditView(
                    isNewTemplate: true,
                    existingTemplate: nil,
                    initialTemplateName: createTemplatePrefillName,
                    initialTemplateNotes: createTemplatePrefillNotes,
                    initialExercises: createTemplatePrefillExercises
                )
            }
            .sheet(item: $selectedTemplate, onDismiss: {
                selectedTemplate = nil
                viewModel.refreshTemplates() // Refresh on dismiss
            }) { template in
                if currentAction == .edit {
                    TemplateEditView(
                        isNewTemplate: false,
                        existingTemplate: template,
                        initialTemplateName: "",
                        initialTemplateNotes: "",
                        initialExercises: []
                    )
                } else {
                    let templateCannotStartOnItsOwn = templateManager.startWorkoutDisabledMessage(for: template) != nil
                    TemplateDetailView(
                        template: template,
                        onStartWorkout: { workout in
                            activeWorkoutBinding = workout
                            selectedTemplate = nil
                        },
                        onEditTemplate: {
                            currentAction = .edit
                        },
                        onDuplicateTemplate: {
                            selectedTemplate = nil
                            startDuplicating(template)
                        },
                        onResumeActiveWorkout: protectedResumableWorkout() == nil
                            ? nil
                            : {
                                selectedTemplate = nil
                                showActiveWorkoutSheet = true
                            },
                        onSaveActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil
                            ? nil
                            : {
                                saveActiveWorkoutAndOpenTemplate(template)
                            },
                        onDiscardActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil
                            ? nil
                            : {
                                discardActiveWorkoutAndOpenTemplate(template)
                            },
                        activeWorkoutBlockMessage: protectedResumableWorkout().map {
                            viewModel.activeWorkoutBlocksTemplateStartMessage(for: $0, opening: template)
                        }
                    )
                }
            }
            .confirmationDialog(
                "Delete Template",
                isPresented: $showingConfirmationDialog,
                presenting: templateToDelete
            ) { template in
                Button("Delete \(WorkoutTemplate.normalizedDisplayName(template.name))", role: .destructive) {
                    let result = viewModel.deleteTemplate(template)
                    if result != .success {
                        deleteResult = result
                    }
                }
            } message: { template in
                Text("Are you sure you want to delete this template? This action cannot be undone.")
            }
            .onAppear {
                viewModel.refreshTemplates()
            }
            .alert(
                deleteResult?.alertTitle ?? "Unable to Delete Template",
                isPresented: Binding(
                    get: { deleteResult != nil },
                    set: { isPresented in
                        if !isPresented {
                            deleteResult = nil
                        }
                    }
                ),
                presenting: deleteResult
            ) { _ in
                Button("OK", role: .cancel) {
                    deleteResult = nil
                }
            } message: { result in
                Text(result.alertMessage)
            }
            .alert(
                quickStartTemplate.map { templateManager.startWorkoutActionTitle(for: $0) } ?? "Start Workout",
                isPresented: Binding(
                    get: { quickStartTemplate != nil && quickStartConfirmationMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            quickStartTemplate = nil
                            quickStartConfirmationMessage = nil
                        }
                    }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    quickStartTemplate = nil
                    quickStartConfirmationMessage = nil
                }

                Button(quickStartTemplate.map { templateManager.startWorkoutActionTitle(for: $0) } ?? "Start Workout") {
                    confirmQuickStart()
                }
            } message: {
                Text(quickStartConfirmationMessage ?? "")
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
        }
    }

    private func summaryColor(for tone: TemplateManager.TemplateStatusTone) -> Color {
        switch tone {
        case .ready:
            return .secondary
        case .warning, .blocked:
            return .orange
        case .blockedByActiveWorkout:
            return .gray
        }
    }

    private func statusBadgeForegroundColor(for tone: TemplateManager.TemplateStatusTone) -> Color {
        switch tone {
        case .ready:
            return .green
        case .warning, .blocked:
            return .orange
        case .blockedByActiveWorkout:
            return .gray
        }
    }

    private func statusBadgeBackgroundColor(for tone: TemplateManager.TemplateStatusTone) -> Color {
        switch tone {
        case .ready:
            return Color.green.opacity(0.14)
        case .warning, .blocked:
            return Color.orange.opacity(0.16)
        case .blockedByActiveWorkout:
            return Color.gray.opacity(0.16)
        }
    }

    private func protectedResumableWorkout() -> Workout? {
        WorkoutStateManager.shared.resolvedResumableWorkout(
            currentBinding: activeWorkoutBinding,
            fallbackWorkouts: WorkoutManager.shared.getIncompleteWorkouts()
        )
    }

    private func beginQuickStart(for template: WorkoutTemplate) {
        if let confirmationMessage = templateManager.partialStartConfirmationMessage(for: template) {
            quickStartTemplate = template
            quickStartConfirmationMessage = confirmationMessage
            return
        }

        performQuickStart(template)
    }

    private func confirmQuickStart() {
        guard let template = quickStartTemplate else { return }
        quickStartTemplate = nil
        quickStartConfirmationMessage = nil
        performQuickStart(template)
    }

    private func performQuickStart(_ template: WorkoutTemplate) {
        guard let startedWorkout = viewModel.createWorkoutFromTemplate(template) else {
            templateStartFailureMessage = "Your template workout could not be started right now. Please try again."
            return
        }

        activeWorkoutBinding = startedWorkout
        showActiveWorkoutSheet = true
    }

    private func saveActiveWorkoutAndOpenTemplate(_ template: WorkoutTemplate) {
        guard let activeWorkout = protectedResumableWorkout() else { return }

        switch viewModel.startTemplateAfterPersistingActiveWorkout(
            activeWorkout,
            action: .saveForLater,
            opening: template,
            persist: { WorkoutManager.shared.saveWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            activeWorkoutBinding = startedWorkout
            selectedTemplate = nil
        case .failure(let message):
            templateStartFailureMessage = message
        }
    }

    private func discardActiveWorkoutAndOpenTemplate(_ template: WorkoutTemplate) {
        guard let activeWorkout = protectedResumableWorkout() else { return }

        switch viewModel.startTemplateAfterPersistingActiveWorkout(
            activeWorkout,
            action: .discard,
            opening: template,
            persist: { WorkoutManager.shared.deleteWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            activeWorkoutBinding = startedWorkout
            selectedTemplate = nil
        case .failure(let message):
            templateStartFailureMessage = message
        }
    }
}

#Preview {
    NavigationStack {
        TemplatesListView()
            .modelContainer(for: [Exercise.self, Workout.self, ExerciseSet.self, WorkoutTemplate.self, UserSettings.self, User.self])
    }
}
