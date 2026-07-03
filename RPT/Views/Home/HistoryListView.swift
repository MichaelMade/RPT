//
//  HistoryListView.swift
//  RPT
//
//  Complete workout history grouped by month, with swipe-to-delete.
//

import SwiftUI

struct HistoryListView: View {
    @State private var completedWorkouts: [Workout] = []
    @State private var workoutToDelete: Workout?
    @State private var errorMessage: String?

    private let workoutManager = WorkoutManager.shared
    private let calendar = Calendar.current

    private struct MonthGroup: Identifiable {
        let monthStart: Date
        let workouts: [Workout]

        var id: Date { monthStart }
    }

    private var monthGroups: [MonthGroup] {
        let grouped = Dictionary(grouping: completedWorkouts) { workout in
            calendar.dateInterval(of: .month, for: workout.date)?.start
                ?? calendar.startOfDay(for: workout.date)
        }

        return grouped
            .map { MonthGroup(monthStart: $0.key, workouts: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.monthStart > $1.monthStart }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                if completedWorkouts.isEmpty {
                    EmptyStateCard(
                        icon: "clock",
                        title: "No History Yet",
                        message: "Completed workouts land here, grouped by month."
                    )
                } else {
                    ForEach(monthGroups) { group in
                        VStack(spacing: 12) {
                            HStack {
                                Text(group.monthStart, format: .dateTime.month(.wide).year())
                                    .font(.headline)
                                Spacer()
                                Text(monthSummary(for: group))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(group.workouts) { workout in
                                NavigationLink {
                                    WorkoutDetailView(workout: workout)
                                } label: {
                                    WorkoutCard(workout: workout)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        workoutToDelete = workout
                                    } label: {
                                        Label("Delete Workout", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .background(Theme.screenBackground)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refresh()
        }
        .alert(item: $workoutToDelete) { workout in
            Alert(
                title: Text("Delete This Workout?"),
                message: Text("This permanently removes the session and its logged sets from your history."),
                primaryButton: .destructive(Text("Delete")) {
                    if workoutManager.deleteWorkoutSafely(workout) {
                        refresh()
                    } else {
                        errorMessage = "Couldn’t delete this workout. Please try again."
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Couldn’t Delete Workout", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private func refresh() {
        completedWorkouts = workoutManager
            .getWorkouts(from: .distantPast, to: Date())
            .filter(\.isCompleted)
            .sorted { $0.date > $1.date }
    }

    private func monthSummary(for group: MonthGroup) -> String {
        let count = group.workouts.count
        return count == 1 ? "1 workout" : "\(count) workouts"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
