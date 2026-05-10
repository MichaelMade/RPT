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
                        Text(
                            viewModel.hasActiveSearch
                            ? "Try a different search, clear it to browse every workout template, or create a new template from this search. You can search names, exercises, notes, and issue labels like missing or repeated."
                            : "Create your first workout template to quickly start repeatable RPT sessions."
                        )
                    } actions: {
                        if let createRecoveryTitle {
                            Button(createRecoveryTitle) {
                                createTemplatePrefillName = viewModel.suggestedTemplateNameForEmptySearch(filteredCount: filteredTemplates.count) ?? ""
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
                                createTemplatePrefillName = viewModel.preferredNewTemplatePrefillName()
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

                            Button(role: .destructive) {
                                templateToDelete = template
                                showingConfirmationDialog = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    if viewModel.shouldShowCreateTemplateFromSearchAction(filteredCount: filteredTemplates.count),
                       let createRecoveryTitle = viewModel.createTemplateRecoveryTitle(filteredCount: filteredTemplates.count) {
                        Button(createRecoveryTitle) {
                            createTemplatePrefillName = viewModel.suggestedTemplateNameFromSearch() ?? ""
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
                        createTemplatePrefillName = viewModel.preferredNewTemplatePrefillName()
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
                    initialTemplateName: createTemplatePrefillName
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
                        initialTemplateName: ""
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
