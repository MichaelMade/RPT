//
//  HistoryListView.swift
//  RPT
//
//  Complete workout history grouped by month, with delete via context menu.
//

import SwiftData
import SwiftUI

struct HistoryListView: View {
    @State private var completedWorkouts: [Workout] = []
    @State private var prCounts: [PersistentIdentifier: Int] = [:]
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
            VStack(spacing: 16) {
                if completedWorkouts.isEmpty {
                    EmptyStateCard(
                        icon: "clock",
                        title: "No History Yet",
                        message: "Completed workouts land here, grouped by month."
                    )
                } else {
                    ForEach(monthGroups) { group in
                        VStack(spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(group.monthStart, format: .dateTime.month(.wide).year())
                                    .font(Theme.titleFont(size: 16))
                                    .foregroundStyle(Theme.textPrimary)

                                Spacer()

                                Text(monthSummary(for: group))
                                    .font(.system(size: 13))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.horizontal, 2)

                            VStack(spacing: 0) {
                                ForEach(Array(group.workouts.enumerated()), id: \.element.id) { index, workout in
                                    NavigationLink {
                                        WorkoutDetailView(workout: workout)
                                    } label: {
                                        WorkoutCard(workout: workout, prCount: prCounts[workout.id] ?? 0)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            workoutToDelete = workout
                                        } label: {
                                            Label("Delete Workout", systemImage: "trash")
                                        }
                                    }

                                    if index < group.workouts.count - 1 {
                                        Rectangle()
                                            .fill(Theme.hairline)
                                            .frame(height: 1)
                                    }
                                }
                            }
                            .rptCard(padding: 0)
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
        let completedAscending = workoutManager
            .getWorkouts(from: .distantPast, to: Date())
            .filter(\.isCompleted)

        prCounts = WorkoutPRCounter.counts(forCompletedWorkoutsAscending: completedAscending)
        completedWorkouts = completedAscending.sorted { $0.date > $1.date }
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
