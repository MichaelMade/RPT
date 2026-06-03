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
    @State private var failedTemplateDeletionTarget: WorkoutTemplate?
    @State private var templateStartFailureTitle = "Workout Action Failed"
    @State private var templateStartFailureMessage: String?
    @State private var searchText = ""
    @State private var createTemplatePrefillName = ""
    @State private var createTemplatePrefillNotes = ""
    @State private var createTemplatePrefillExercises: [TemplateExercise] = []
    @State private var quickStartTemplate: WorkoutTemplate?
    @State private var quickStartConfirmationMessage: String?
    @State private var templateToDiscardAndStart: WorkoutTemplate?
    @State private var showingDiscardAndStartConfirmation = false
    
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

    private func presentTemplateStartFailure(_ message: String, title: String = "Workout Action Failed") {
        templateStartFailureTitle = title
        templateStartFailureMessage = message
    }

    private func clearTemplateStartFailure() {
        templateStartFailureTitle = "Workout Action Failed"
        templateStartFailureMessage = nil
    }
    
    var body: some View {
        NavigationStack {
            List {
                let resumableWorkout = protectedResumableWorkout()
                let activeWorkoutBlocksTemplateStart = resumableWorkout != nil
                let filteredTemplates = viewModel.fetchTemplates(
                    blockedByActiveWorkout: activeWorkoutBlocksTemplateStart,
                    activeWorkout: resumableWorkout
                )

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
                        if viewModel.shouldShowEmptyStateContinueWorkoutAction(workout: resumableWorkout) {
                            Button(viewModel.emptyStateContinueWorkoutButtonTitle(for: resumableWorkout)) {
                                showActiveWorkoutSheet = true
                            }
                        }

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
                            let statusTitle = templateManager.startWorkoutActionTitle(
                                for: template,
                                blockedByActiveWorkout: isBlockedByActiveWorkout,
                                blockingWorkout: resumableWorkout
                            )

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
                                    Text(
                                        templateManager.templateListExerciseSummary(
                                            for: template,
                                            blockedByActiveWorkout: isBlockedByActiveWorkout,
                                            blockingWorkout: resumableWorkout
                                        )
                                    )
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
                                Label(viewModel.editTemplateButtonTitle(for: template), systemImage: "pencil")
                            }
                            .tint(.blue)

                            Button {
                                startDuplicating(template)
                            } label: {
                                Label(viewModel.duplicateTemplateButtonTitle(for: template), systemImage: "plus.square.on.square")
                            }
                            .tint(.indigo)

                            Button(role: .destructive) {
                                templateToDelete = template
                                showingConfirmationDialog = true
                            } label: {
                                Label(viewModel.deleteTemplateButtonTitle(for: template), systemImage: "trash")
                            }
                        }
                    }

                    if viewModel.shouldShowSingleTemplateQuickActions(filteredCount: filteredTemplates.count),
                       let matchedTemplate = filteredTemplates.first {
                        Section("Quick Actions") {
                            let quickActionMode = viewModel.quickActionMode(
                                for: matchedTemplate,
                                activeWorkoutBlocksStart: activeWorkoutBlocksTemplateStart,
                                resumableWorkout: resumableWorkout
                            )

                            switch quickActionMode {
                            case .startTemplate:
                                Button(viewModel.quickStartTemplateButtonTitle(for: matchedTemplate)) {
                                    beginQuickStart(for: matchedTemplate)
                                }

                            case .activeWorkoutHandoff:
                                if let resumableWorkout {
                                    Button(viewModel.continueCurrentWorkoutButtonTitle(for: resumableWorkout)) {
                                        showActiveWorkoutSheet = true
                                    }

                                    Button(viewModel.saveAndStartTemplateButtonTitle(for: matchedTemplate, currentWorkout: resumableWorkout)) {
                                        saveActiveWorkoutAndOpenTemplate(matchedTemplate)
                                    }

                                    Button(role: .destructive) {
                                        templateToDiscardAndStart = matchedTemplate
                                        showingDiscardAndStartConfirmation = true
                                    } label: {
                                        Label(
                                            viewModel.discardAndStartTemplateButtonTitle(
                                                for: matchedTemplate,
                                                currentWorkout: resumableWorkout
                                            ),
                                            systemImage: "trash"
                                        )
                                    }
                                }

                            case .continueOnly:
                                if let resumableWorkout {
                                    Button(viewModel.continueCurrentWorkoutButtonTitle(for: resumableWorkout)) {
                                        showActiveWorkoutSheet = true
                                    }
                                }

                            case .none:
                                EmptyView()
                            }

                            Button(viewModel.reviewTemplateButtonTitle(for: matchedTemplate)) {
                                selectedTemplate = matchedTemplate
                                currentAction = .detail
                            }

                            Button(viewModel.editTemplateButtonTitle(for: matchedTemplate)) {
                                selectedTemplate = matchedTemplate
                                currentAction = .edit
                            }

                            Button(viewModel.duplicateTemplateButtonTitle(for: matchedTemplate)) {
                                startDuplicating(matchedTemplate)
                            }

                            Button(role: .destructive) {
                                templateToDelete = matchedTemplate
                                showingConfirmationDialog = true
                            } label: {
                                Label(
                                    viewModel.deleteTemplateButtonTitle(for: matchedTemplate),
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
            .searchable(text: $searchText, prompt: "Search templates, exercises, actions, issues, or find/open/restart wording")
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
                        currentActiveWorkout: protectedResumableWorkout(),
                        activeWorkoutBlockMessage: protectedResumableWorkout().map {
                            viewModel.activeWorkoutBlocksTemplateStartMessage(for: $0, opening: template)
                        }
                    )
                }
            }
            .confirmationDialog(
                viewModel.deleteTemplateAlertTitle(for: templateToDelete),
                isPresented: $showingConfirmationDialog,
                presenting: templateToDelete
            ) { template in
                Button(viewModel.deleteTemplateButtonTitle(for: template), role: .destructive) {
                    let result = viewModel.deleteTemplate(template)
                    if result != .success {
                        failedTemplateDeletionTarget = template
                        deleteResult = result
                    }
                }
            } message: { template in
                Text(viewModel.deleteTemplateMessage(for: template))
            }
            .onAppear {
                viewModel.refreshTemplates()
            }
            .alert(
                viewModel.deleteTemplateFailureAlertTitle(for: failedTemplateDeletionTarget),
                isPresented: Binding(
                    get: { deleteResult != nil },
                    set: { isPresented in
                        if !isPresented {
                            deleteResult = nil
                            failedTemplateDeletionTarget = nil
                        }
                    }
                ),
                presenting: deleteResult
            ) { _ in
                Button("OK", role: .cancel) {
                    deleteResult = nil
                    failedTemplateDeletionTarget = nil
                }
            } message: { _ in
                Text(viewModel.deleteTemplateFailureMessage(for: failedTemplateDeletionTarget))
            }
            .alert(
                quickStartTemplate.map { viewModel.quickStartTemplateButtonTitle(for: $0) } ?? "Start This Template",
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

                Button(quickStartTemplate.map { viewModel.quickStartTemplateButtonTitle(for: $0) } ?? "Start This Template") {
                    confirmQuickStart()
                }
            } message: {
                Text(quickStartConfirmationMessage ?? "")
            }
            .alert(
                templateToDiscardAndStart.map {
                    viewModel.discardCurrentWorkoutAndStartTemplateAlertTitle(
                        for: $0,
                        currentWorkout: protectedResumableWorkout()
                    )
                } ?? "Discard This Workout & Start This Template?",
                isPresented: $showingDiscardAndStartConfirmation,
                presenting: templateToDiscardAndStart
            ) { template in
                Button(
                    viewModel.discardAndStartTemplateButtonTitle(
                        for: template,
                        currentWorkout: protectedResumableWorkout()
                    ),
                    role: .destructive
                ) {
                    discardActiveWorkoutAndOpenTemplate(template)
                    templateToDiscardAndStart = nil
                }

                Button("Cancel", role: .cancel) {
                    templateToDiscardAndStart = nil
                }
            } message: { template in
                Text(
                    viewModel.discardCurrentWorkoutAndStartTemplateAlertMessage(
                        for: template,
                        currentWorkout: protectedResumableWorkout()
                    )
                )
            }
            .alert(templateStartFailureTitle, isPresented: Binding(
                get: { templateStartFailureMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        clearTemplateStartFailure()
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    clearTemplateStartFailure()
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
            presentTemplateStartFailure(
                viewModel.startTemplateFailureMessage(for: template),
                title: viewModel.startTemplateFailureAlertTitle(for: template)
            )
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
            showActiveWorkoutSheet = true
        case .failure(let message):
            presentTemplateStartFailure(
                message,
                title: viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, opening: template)
            )
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
            showActiveWorkoutSheet = true
        case .failure(let message):
            presentTemplateStartFailure(
                message,
                title: viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .discard, opening: template)
            )
        }
    }
}

#Preview {
    NavigationStack {
        TemplatesListView()
            .modelContainer(for: [Exercise.self, Workout.self, ExerciseSet.self, WorkoutTemplate.self, UserSettings.self, User.self])
    }
}
