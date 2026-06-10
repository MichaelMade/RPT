//
//  TemplatesListView.swift
//  RPT
//
//  Saved routines: search, start, duplicate, edit, and delete.
//

import SwiftUI

struct TemplatesListView: View {
    @EnvironmentObject private var session: WorkoutSession
    @StateObject private var viewModel = TemplateViewModel()

    @State private var showingCreateTemplate = false
    @State private var templateToDelete: WorkoutTemplate?
    @State private var pendingStartTemplate: WorkoutTemplate?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.templates.isEmpty {
                        EmptyStateCard(
                            icon: "square.grid.2x2",
                            title: "No Templates Yet",
                            message: "Save your favorite routines as templates and start them with one tap.",
                            actionTitle: "Create Template"
                        ) {
                            showingCreateTemplate = true
                        }
                    } else if viewModel.filteredTemplates.isEmpty {
                        EmptyStateCard(
                            icon: "magnifyingglass",
                            title: "No Matches",
                            message: "No template matches “\(viewModel.searchText)”. Search by name, notes, exercise, or muscle group."
                        )
                    } else {
                        ForEach(viewModel.filteredTemplates) { template in
                            templateCard(template)
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Theme.screenBackground)
            .searchable(text: $viewModel.searchText, prompt: "Search templates")
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateTemplate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateTemplate) {
                TemplateEditView(mode: .create) {
                    viewModel.refreshTemplates()
                }
            }
            .onAppear {
                viewModel.refreshTemplates()
                session.restoreResumableWorkout()
            }
            .alert(item: $templateToDelete) { template in
                Alert(
                    title: Text("Delete “\(template.name)”?"),
                    message: Text("This removes the template. Your workout history is not affected."),
                    primaryButton: .destructive(Text("Delete")) {
                        if !viewModel.deleteTemplate(template) {
                            errorMessage = "Couldn’t delete this template. Please try again."
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .confirmationDialog(
                "Workout in Progress",
                isPresented: pendingStartBinding,
                titleVisibility: .visible
            ) {
                Button("Save Current & Start Template") {
                    resolveBlockedStart(discard: false)
                }
                Button("Discard Current & Start Template", role: .destructive) {
                    resolveBlockedStart(discard: true)
                }
                Button("Cancel", role: .cancel) {
                    pendingStartTemplate = nil
                }
            } message: {
                Text("Save your current workout for later or discard it before starting this template.")
            }
            .alert("Couldn’t Start Template", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    // MARK: - Card

    private func templateCard(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                TemplateDetailView(template: template) {
                    viewModel.refreshTemplates()
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(template.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    Text(exerciseSummary(for: template))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if !viewModel.missingExerciseNames(in: template).isEmpty {
                        PillTag(text: "Missing exercises", tint: Theme.amber, icon: "exclamationmark.triangle.fill")
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    requestStart(template)
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(SecondaryCapsuleButtonStyle())
                .disabled(!viewModel.canStart(template))

                Spacer()

                Menu {
                    Button {
                        if !viewModel.duplicateTemplate(template) {
                            errorMessage = "Couldn’t duplicate this template. Please try again."
                        }
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }

                    Button(role: .destructive) {
                        templateToDelete = template
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
        }
        .rptCard()
    }

    private func exerciseSummary(for template: WorkoutTemplate) -> String {
        let names = template.exercises.map(\.exerciseName)
        guard !names.isEmpty else {
            return "No exercises yet"
        }

        let preview = names.prefix(3).joined(separator: ", ")
        let extra = names.count - 3
        return extra > 0 ? "\(preview) +\(extra) more" : preview
    }

    // MARK: - Start Flow

    private func requestStart(_ template: WorkoutTemplate) {
        session.restoreResumableWorkout()

        if session.resumableWorkout != nil {
            pendingStartTemplate = template
        } else {
            startTemplate(template)
        }
    }

    private func resolveBlockedStart(discard: Bool) {
        guard let template = pendingStartTemplate else { return }
        pendingStartTemplate = nil

        let cleared = discard ? session.discardCurrent() : session.saveCurrentForLater()
        guard cleared else {
            errorMessage = discard
                ? "Couldn’t discard the current workout. Keep it open, then try again."
                : "Couldn’t save the current workout. Keep it open, then try again."
            return
        }

        startTemplate(template)
    }

    private func startTemplate(_ template: WorkoutTemplate) {
        guard let workout = viewModel.createWorkout(from: template) else {
            errorMessage = "Couldn’t start this template. Make sure its exercises are still in your library."
            return
        }

        session.start(workout)
    }

    // MARK: - Bindings

    private var pendingStartBinding: Binding<Bool> {
        Binding(
            get: { pendingStartTemplate != nil },
            set: { if !$0 { pendingStartTemplate = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
