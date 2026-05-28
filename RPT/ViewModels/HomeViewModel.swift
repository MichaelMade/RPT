//
//  HomeViewModel.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class HomeViewModel: ObservableObject {
    enum StartFreshPersistenceAction {
        case saveForLater
        case discard
    }

    typealias FollowUpPersistenceAction = StartFreshPersistenceAction

    private let workoutManager: WorkoutManager
    private let userManager: UserManager
    private let templateManager: TemplateManager

    @Published var recentWorkouts: [Workout] = []
    @Published var currentWorkout: Workout?
    @Published var userStats: (totalWorkouts: Int, totalVolume: Double, workoutStreak: Int)?
    @Published var lifetimeWorkMetricTitle: String = "Volume"
    @Published var lifetimeWorkMetricValue: String = "0"
    @Published var lifetimeWorkMetricSubtitle: String = "lb lifted"
    @Published var startWorkoutFailureAlertTitle: String = "Workout Action Failed"
    @Published var startWorkoutFailureMessage: String?

    init(workoutManager: WorkoutManager? = nil,
         userManager: UserManager? = nil,
         templateManager: TemplateManager? = nil) {
        self.workoutManager = workoutManager ?? WorkoutManager.shared
        self.userManager = userManager ?? UserManager.shared
        self.templateManager = templateManager ?? TemplateManager.shared
    }

    func loadRecentWorkouts() {
        let now = Date()
        let fetchedRecentWorkouts = workoutManager.getRecentWorkouts(limit: 25)
        let allWorkouts = workoutManager.getWorkouts(from: .distantPast, to: now)

        recentWorkouts = resolvedRecentCompletedWorkouts(
            from: fetchedRecentWorkouts,
            fallbackAllWorkouts: allWorkouts,
            limit: 5
        )
        userStats = userManager.getUserStats()

        let completedWorkouts = allWorkouts.filter { $0.isCompleted }
        let totalBodyweightReps = completedWorkouts.reduce(0) { $0 + max(0, $1.totalBodyweightReps) }
        let lifetimeWorkMetric = lifetimeWorkMetric(
            totalVolume: userStats?.totalVolume ?? 0,
            totalBodyweightReps: totalBodyweightReps
        )
        lifetimeWorkMetricTitle = lifetimeWorkMetric.title
        lifetimeWorkMetricValue = lifetimeWorkMetric.value
        lifetimeWorkMetricSubtitle = lifetimeWorkMetric.subtitle

        let workoutStateManager = WorkoutStateManager.shared
        currentWorkout = workoutStateManager.firstResumableWorkout(in: workoutManager.getIncompleteWorkouts())
    }

    @discardableResult
    func startNewWorkout() -> Bool {
        guard let workout = workoutManager.createWorkoutSafely() else {
            currentWorkout = nil
            presentStartWorkoutFailure(
                startNewWorkoutFailureMessage(),
                title: startNewWorkoutFailureAlertTitle()
            )
            return false
        }

        currentWorkout = workout
        clearStartWorkoutFailure()
        return true
    }

    func startNewWorkoutFailureMessage() -> String {
        "Your workout could not be started right now. Please try again."
    }

    func startNewWorkoutFailureAlertTitle() -> String {
        "Couldn’t Start New Workout"
    }

    func canStartFollowUpWorkout(from workout: Workout, activeWorkout: Workout?) -> Bool {
        guard resumableWorkout(activeWorkout: activeWorkout) == nil else {
            return false
        }

        return hasFollowUpContent(in: workout)
    }

    func shouldOfferFollowUpRecovery(for workout: Workout) -> Bool {
        hasFollowUpContent(in: workout)
    }

    @discardableResult
    func startFollowUpWorkout(from workout: Workout) -> Bool {
        guard let followUpWorkout = workoutManager.createFollowUpWorkoutSafely(from: workout) else {
            presentStartWorkoutFailure(
                startFollowUpFailureMessage(for: workout),
                title: startFollowUpFailureAlertTitle(for: workout)
            )
            return false
        }

        currentWorkout = followUpWorkout
        clearStartWorkoutFailure()
        return true
    }

    func startFollowUpAfterPersistingActiveWorkout(
        _ activeWorkout: Workout,
        action: FollowUpPersistenceAction,
        from workout: Workout,
        persist: (Workout) -> Bool
    ) -> Result<Workout, String> {
        guard persistWorkoutForFreshStart(activeWorkout, action: action, persist: persist) else {
            return .failure(
                activeWorkoutPersistenceFailureMessage(
                    for: action,
                    currentWorkout: activeWorkout,
                    startingFollowUpFrom: workout
                )
            )
        }

        guard startFollowUpWorkout(from: workout), let currentWorkout else {
            return .failure(startFollowUpFailureMessage(for: workout))
        }

        return .success(currentWorkout)
    }

    func resumeWorkout(_ workout: Workout) {
        currentWorkout = workout
    }

    func resumableWorkout(activeWorkout: Workout?) -> Workout? {
        let workoutStateManager = WorkoutStateManager.shared

        if workoutStateManager.shouldResume(activeWorkout) {
            return activeWorkout
        }

        if workoutStateManager.shouldResume(currentWorkout) {
            return currentWorkout
        }

        return nil
    }

    func canContinueWorkout(activeWorkout: Workout?) -> Bool {
        resumableWorkout(activeWorkout: activeWorkout) != nil
    }

    func resolvedActiveWorkoutBinding(currentBinding: Workout?, storedWorkout: Workout?) -> Workout? {
        WorkoutStateManager.shared.resolvedResumableWorkout(
            currentBinding: currentBinding,
            fallbackWorkouts: [storedWorkout].compactMap { $0 }
        )
    }

    func shouldReloadAfterWorkoutSheetPresentationChange(from oldValue: Bool, to newValue: Bool) -> Bool {
        oldValue && !newValue
    }

    func weeklyWorkoutCount() -> Int {
        let stats = workoutManager.calculateWorkoutStats(timeframe: .week)
        return max(0, stats.count)
    }

    func resumableWorkoutSummary(for workout: Workout, now: Date = Date()) -> String {
        var parts: [String] = [workoutStartedSummary(for: workout.date, now: now)]

        if let templateName = resumableWorkoutSourceTemplateName(for: workout) {
            parts.append("From \(templateName)")
        }

        if workout.sets.isEmpty {
            parts.append("No exercises added yet")
        } else {
            parts.append(exerciseCountTextForResumableSummary(for: workout))
            parts.append(setCountTextForResumableSummary(for: workout))
            parts.append(resumableWorkoutProgressText(for: workout))
        }

        return parts.joined(separator: " • ")
    }

    func continueCurrentWorkoutButtonTitle(for workout: Workout) -> String {
        guard let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Continue Current Workout"
        }

        return "Continue “\(displayName)”"
    }

    func replaceCurrentWorkoutAlertTitle(for workout: Workout) -> String {
        guard let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Replace Current Workout?"
        }

        return "Replace “\(displayName)”?"
    }

    func saveAndStartFreshButtonTitle(for workout: Workout) -> String {
        guard let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Save Current Workout & Start New Workout"
        }

        return "Save “\(displayName)” & Start New Workout"
    }

    func discardAndStartFreshButtonTitle(for workout: Workout) -> String {
        guard let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Discard Current Workout & Start New Workout"
        }

        return "Discard “\(displayName)” & Start New Workout"
    }

    func discardCurrentWorkoutAndStartFreshAlertTitle(for workout: Workout) -> String {
        guard let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Discard Current Workout & Start New Workout?"
        }

        return "Discard “\(displayName)” & Start New Workout?"
    }

    func discardCurrentWorkoutAndStartFreshAlertMessage(for workout: Workout, now: Date = Date()) -> String {
        let workoutSummary = resumableWorkoutSummary(for: workout, now: now)

        guard let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "This will discard your in-progress workout (\(workoutSummary)) and immediately start a new workout. This action cannot be undone."
        }

        return "This will discard “\(displayName)” (\(workoutSummary)) and immediately start a new workout. This action cannot be undone."
    }

    func activeWorkoutInProgressTitle(for workout: Workout?) -> String {
        guard let workout else {
            return "Current Workout In Progress"
        }

        guard let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Current Workout In Progress"
        }

        return "“\(displayName)” In Progress"
    }

    private func exerciseCountTextForResumableSummary(for workout: Workout) -> String {
        let count: Int

        if workout.hasLoggedWarmupOnly {
            count = Set(
                workout.sets
                    .filter(\.isCompletedLoggedSet)
                    .compactMap { $0.exercise }
            ).count
        } else {
            count = WorkoutRow.displayExerciseCount(for: workout)
        }

        return "\(count) \(count == 1 ? \"exercise\" : \"exercises\")"
    }

    private func setCountTextForResumableSummary(for workout: Workout) -> String {
        let count = workout.hasLoggedWarmupOnly
            ? workout.sets.filter(\.isCompletedLoggedSet).count
            : WorkoutRow.displaySetCount(for: workout)

        return "\(count) \(count == 1 ? \"set\" : \"sets\")"
    }

    func resumableWorkoutProgressText(for workout: Workout) -> String {
        let totalExercises = max(0, workout.exerciseCount)
        let startedExercises = startedExerciseCount(for: workout)

        guard totalExercises > 0 else {
            return "No exercises added yet"
        }

        if workout.hasLoggedWarmupOnly {
            return "Warm-up sets only so far"
        }

        if startedExercises <= 0 {
            return totalExercises == 1
                ? "Exercise not started yet"
                : "No exercises started yet"
        }

        if startedExercises >= totalExercises {
            return totalExercises == 1
                ? "Exercise started"
                : "All \(totalExercises) exercises started"
        }

        let exerciseLabel = totalExercises == 1 ? "exercise" : "exercises"
        return "\(startedExercises) of \(totalExercises) \(exerciseLabel) started"
    }

    func startedExerciseCount(for workout: Workout) -> Int {
        Set(
            workout.sets
                .filter(\.isCompletedLoggedSet)
                .compactMap { $0.exercise }
        ).count
    }

    func workoutStartedSummary(
        for startDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var displayCalendar = calendar
        displayCalendar.timeZone = timeZone

        if startDate > now {
            return "Started " + WorkoutRow.relativeDateText(
                for: startDate,
                now: now,
                calendar: displayCalendar,
                locale: locale,
                timeZone: timeZone
            )
        }

        let safeInterval = max(0, now.timeIntervalSince(startDate))

        if displayCalendar.isDate(startDate, inSameDayAs: now) {
            if safeInterval < 60 {
                return "Started just now"
            }

            if safeInterval < 3600 {
                let minutes = max(1, Int(floor(safeInterval / 60)))
                return "Started \(minutes)m ago"
            }

            let hours = max(1, Int(floor(safeInterval / 3600)))
            return "Started \(hours)h ago"
        }

        return "Started " + WorkoutRow.relativeDateText(
            for: startDate,
            now: now,
            calendar: displayCalendar,
            locale: locale,
            timeZone: timeZone
        )
    }

    func calculateWeeklyProgress() -> Double {
        weeklyProgress(forWorkoutCount: weeklyWorkoutCount())
    }

    func weeklyProgress(forWorkoutCount count: Int) -> Double {
        guard count > 0 else { return 0 }
        return min(1.0, Double(count) / 7.0)
    }

    func weeklyProgressSummary(forWorkoutCount count: Int) -> String {
        let safeCount = max(0, count)
        let displayedCount = min(7, safeCount)
        return "\(displayedCount) of 7 workouts"
    }

    func weeklyProgressSubtitle(forWorkoutCount count: Int) -> String {
        let safeCount = max(0, count)

        if safeCount == 0 {
            return "Log a workout to start your weekly streak."
        }

        if safeCount >= 7 {
            return "You've hit your 7-workout pace for the last 7 days."
        }

        let remainingCount = 7 - safeCount
        let remainingLabel = remainingCount == 1 ? "workout" : "workouts"
        return "\(remainingCount) more \(remainingLabel) to fill the last-7-days goal."
    }

    func completedRecentWorkouts(from workouts: [Workout], limit: Int) -> [Workout] {
        guard limit > 0 else { return [] }

        return workouts
            .filter { $0.isCompleted }
            .sorted(by: { $0.date > $1.date })
            .prefix(limit)
            .map { $0 }
    }

    func resolvedRecentCompletedWorkouts(from recentSlice: [Workout], fallbackAllWorkouts: [Workout]?, limit: Int) -> [Workout] {
        let recentCompleted = completedRecentWorkouts(from: recentSlice, limit: limit)

        guard recentCompleted.count < limit else {
            return recentCompleted
        }

        let allWorkouts = fallbackAllWorkouts ?? workoutManager.getWorkouts(from: .distantPast, to: Date())

        return completedRecentWorkouts(from: allWorkouts, limit: limit)
    }

    func recentWorkoutsEmptyState(activeWorkout: Workout?) -> (title: String, subtitle: String) {
        if resumableWorkout(activeWorkout: activeWorkout) != nil {
            return (
                title: "No completed workouts yet",
                subtitle: "Finish your current workout to see it show up here with your latest stats."
            )
        }

        return (
            title: "No recent workouts yet",
            subtitle: "Complete a workout and your latest sessions will show up here for quick review."
        )
    }

    func shouldShowSingleRecentWorkoutQuickActions(recentWorkoutCount: Int) -> Bool {
        recentWorkoutCount == 1
    }

    func deleteRecentWorkout(_ workout: Workout) -> Bool {
        guard workoutManager.deleteWorkoutSafely(workout) else {
            presentStartWorkoutFailure(
                deleteRecentWorkoutFailureMessage(for: workout),
                title: deleteRecentWorkoutFailureAlertTitle(for: workout)
            )
            return false
        }

        clearStartWorkoutFailure()
        loadRecentWorkouts()
        return true
    }

    func deleteRecentWorkoutAlertTitle(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Delete This Workout?"
        }

        return "Delete “\(displayName)”?"
    }

    func deleteRecentWorkoutMessage(for workout: Workout, now: Date = Date()) -> String {
        var summaryParts = [WorkoutRow.relativeDateText(for: workout.date, now: now)]
        summaryParts.append(savedWorkoutSessionSummary(for: workout))

        let target = WorkoutRow.specificDisplayName(for: workout) ?? "this workout"
        return "Delete \(target) from history? \(summaryParts.joined(separator: " • ")) will be removed from your saved workout history."
    }

    private func savedWorkoutSessionSummary(for workout: Workout) -> String {
        if let countsFallbackText = WorkoutRow.countsFallbackText(for: workout) {
            return countsFallbackText
        }

        let loggedSets = workout.sets.filter(\.isCompletedLoggedSet)
        let warmupCount = loggedSets.filter(\.isWarmup).count
        let workingCount = loggedSets.count - warmupCount

        if workingCount > 0, warmupCount > 0 {
            let totalLoggedSetSummary = "\(loggedSets.count) logged sets"
            let workingSummary = "\(workingCount) working"
            let warmupSummary = "\(warmupCount) warm-up"
            return "\(WorkoutRow.exerciseCountText(for: workout)) • \(totalLoggedSetSummary) (\(workingSummary), \(warmupSummary))"
        }

        if workingCount > 0 {
            let workingSetSummary = workingCount == 1 ? "1 working set" : "\(workingCount) working sets"
            return "\(WorkoutRow.exerciseCountText(for: workout)) • \(workingSetSummary)"
        }

        return "\(WorkoutRow.exerciseCountText(for: workout)) • \(WorkoutRow.setCountText(for: workout))"
    }

    private func recentWorkoutSessionSummary(for workout: Workout) -> String {
        savedWorkoutSessionSummary(for: workout)
    }

    private func specificSavedWorkoutName(for workout: Workout) -> String? {
        WorkoutRow.specificDisplayName(for: workout)
    }

    func deleteRecentWorkoutFailureMessage(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Couldn’t delete this workout from history. Keep it for now, then try again."
        }

        return "Couldn’t delete \(displayName) from history. Keep it for now, then try again."
    }

    func deleteRecentWorkoutFailureAlertTitle(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Couldn’t Delete This Workout"
        }

        return "Couldn’t Delete “\(displayName)”"
    }

    func presentStartWorkoutFailure(_ message: String, title: String = "Workout Action Failed") {
        startWorkoutFailureAlertTitle = title
        startWorkoutFailureMessage = message
    }

    func clearStartWorkoutFailure() {
        startWorkoutFailureAlertTitle = "Workout Action Failed"
        startWorkoutFailureMessage = nil
    }

    func reviewWorkoutButtonTitle(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Review Workout"
        }

        return "Review “\(displayName)”"
    }

    func copySummaryButtonTitle(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Copy Workout Summary"
        }

        return "Copy Summary for “\(displayName)”"
    }

    func deleteRecentWorkoutButtonTitle(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Delete Workout from History"
        }

        return "Delete “\(displayName)” from History"
    }

    func deleteRecentWorkoutConfirmationButtonTitle(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Delete This Workout"
        }

        return "Delete “\(displayName)”"
    }

    func startFollowUpFailureMessage(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Couldn’t start this follow-up. Keep this workout in history, then try again."
        }

        return "Couldn’t start a follow-up from “\(displayName)”. Keep it in history, then try again."
    }

    func startFollowUpFailureAlertTitle(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Couldn’t Start This Follow-Up"
        }

        return "Couldn’t Start Follow-Up from “\(displayName)”"
    }

    func followUpWorkoutButtonTitle(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Start This Follow-Up"
        }

        return "Start Follow-Up from “\(displayName)”"
    }

    func saveAndStartFollowUpButtonTitle(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Save & Start This Follow-Up"
        }

        return "Save & Start Follow-Up from “\(displayName)”"
    }

    func discardAndStartFollowUpButtonTitle(for workout: Workout) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "Discard & Start This Follow-Up"
        }

        return "Discard & Start Follow-Up from “\(displayName)”"
    }

    func discardCurrentWorkoutAndStartFollowUpAlertTitle(for workout: Workout, currentWorkout: Workout? = nil) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "\(discardCurrentWorkoutTitlePrefix(for: currentWorkout)) & Start This Follow-Up?"
        }

        return "\(discardCurrentWorkoutTitlePrefix(for: currentWorkout)) & Start Follow-Up from “\(displayName)”?"
    }

    func discardCurrentWorkoutAndStartFollowUpAlertMessage(for workout: Workout, currentWorkout: Workout? = nil) -> String {
        let sourceSummary = recentWorkoutSessionSummary(for: workout)

        guard let displayName = specificSavedWorkoutName(for: workout) else {
            return "\(discardCurrentWorkoutMessageSubject(for: currentWorkout)) will be lost and RPT will immediately start the selected follow-up. Source session: \(sourceSummary). This action cannot be undone."
        }

        return "\(discardCurrentWorkoutMessageSubject(for: currentWorkout)) will be lost and RPT will immediately start a follow-up from “\(displayName)”. Source session: \(sourceSummary). This action cannot be undone."
    }

    private func discardCurrentWorkoutTitlePrefix(for workout: Workout?) -> String {
        guard let workout, let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Discard Current Workout"
        }

        return "Discard “\(displayName)”"
    }

    private func discardCurrentWorkoutMessageSubject(for workout: Workout?) -> String {
        guard let workout, let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Your in-progress workout"
        }

        return "“\(displayName)”"
    }

    func startTemplateFailureAlertTitle(for template: WorkoutTemplate) -> String {
        TemplateViewModel().startTemplateFailureAlertTitle(for: template)
    }

    func sourceTemplateQuickActionTitle(
        for workout: Workout,
        resolvedTemplateName: String? = nil,
        resolvedTemplate: WorkoutTemplate? = nil
    ) -> String? {
        if let resolvedTemplate {
            return TemplateViewModel().startTemplateButtonTitle(for: resolvedTemplate)
        }

        let preferredTemplateName = normalizedSummaryName(resolvedTemplateName)
            ?? normalizedSummaryName(workout.startedFromTemplate)

        guard let templateName = preferredTemplateName else {
            return nil
        }

        let displayName = WorkoutTemplate.normalizedDisplayName(templateName)
        return displayName == "Template"
            ? "Start This Template"
            : "Start Template “\(displayName)”"
    }

    func followUpWorkoutHelperText(for workout: Workout) -> String {
        "Create a new draft with your last working-set weights prefilled so you can keep progressing without rebuilding the session."
    }

    func activeWorkoutBlocksFollowUpMessage(for activeWorkout: Workout, startingFrom workout: Workout, now: Date = Date()) -> String {
        let activeWorkoutSummary = resumableWorkoutSummary(for: activeWorkout, now: now)

        guard let followUpName = specificSavedWorkoutName(for: workout) else {
            return "You already have a workout in progress: \(activeWorkoutSummary). Continue it, save it for later, or discard it before starting this follow-up."
        }

        return "You already have a workout in progress: \(activeWorkoutSummary). Continue it, save it for later, or discard it before starting a follow-up from “\(followUpName)”."
    }

    func startFreshWorkoutPromptPrefix(for workout: Workout) -> String {
        guard let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "You already have a workout in progress:"
        }

        return "You already have “\(displayName)” in progress:"
    }

    func startFreshWorkoutMessage(for workout: Workout, now: Date = Date()) -> String {
        "\(startFreshWorkoutPromptPrefix(for: workout)) \(resumableWorkoutSummary(for: workout, now: now)). Save it for later, discard it, or keep going."
    }

    func shouldResumeIncompleteWorkout(workoutDate: Date?, discardTimestamp: Date?, wasAnyWorkoutDiscarded: Bool) -> Bool {
        guard let workoutDate else { return false }

        guard wasAnyWorkoutDiscarded else {
            return true
        }

        guard let discardTimestamp else {
            // Fail open for legacy/corrupted discard state that is missing timestamp.
            // Hiding a valid resumable workout is worse UX than allowing resume.
            return true
        }

        return workoutDate >= discardTimestamp
    }

    func persistWorkoutForFreshStart(
        _ workout: Workout,
        action: StartFreshPersistenceAction,
        persist: (Workout) -> Bool
    ) -> Bool {
        guard persist(workout) else {
            return false
        }

        switch action {
        case .saveForLater:
            WorkoutStateManager.shared.markWorkoutAsSaved(workout.id)
        case .discard:
            WorkoutStateManager.shared.markWorkoutAsDiscarded(workout.id)
        }

        return true
    }

    func startFreshFailureAlertTitle(for action: StartFreshPersistenceAction, currentWorkout: Workout? = nil) -> String {
        let namedTitle: (String) -> String = { actionLabel in
            guard let currentWorkout,
                  let displayName = WorkoutRow.specificDisplayName(for: currentWorkout) else {
                return "Couldn’t \(actionLabel) New Workout"
            }

            return "Couldn’t \(actionLabel) “\(displayName)”"
        }

        switch action {
        case .saveForLater:
            return namedTitle("Save & Start")
        case .discard:
            return namedTitle("Discard & Start")
        }
    }

    func startFreshFailureMessage(for action: StartFreshPersistenceAction, currentWorkout: Workout? = nil) -> String {
        let draftReference = currentWorkout
            .flatMap { WorkoutRow.specificDisplayName(for: $0) }
            .map { "“\($0)”" } ?? "the current workout"

        switch action {
        case .saveForLater:
            return "Couldn’t save \(draftReference). Keep this draft open, then try again."
        case .discard:
            return "Couldn’t discard \(draftReference). Keep this draft open, then try again."
        }
    }

    func activeWorkoutPersistenceFailureMessage(
        for action: FollowUpPersistenceAction,
        currentWorkout: Workout? = nil,
        startingFollowUpFrom workout: Workout
    ) -> String {
        let draftReference = currentWorkout
            .flatMap { WorkoutRow.specificDisplayName(for: $0) }
            .map { "“\($0)”" } ?? "the current workout"

        guard let followUpName = specificSavedWorkoutName(for: workout) else {
            switch action {
            case .saveForLater:
                return "Couldn’t save \(draftReference). Keep it open, then try starting this follow-up again."
            case .discard:
                return "Couldn’t discard \(draftReference). Keep it open, then try starting this follow-up again."
            }
        }

        switch action {
        case .saveForLater:
            return "Couldn’t save \(draftReference). Keep it open, then try starting a follow-up from “\(followUpName)” again."
        case .discard:
            return "Couldn’t discard \(draftReference). Keep it open, then try starting a follow-up from “\(followUpName)” again."
        }
    }

    func activeWorkoutPersistenceFailureAlertTitle(
        for action: FollowUpPersistenceAction,
        startingFollowUpFrom workout: Workout
    ) -> String {
        guard let displayName = specificSavedWorkoutName(for: workout) else {
            switch action {
            case .saveForLater:
                return "Couldn’t Save & Start This Follow-Up"
            case .discard:
                return "Couldn’t Discard & Start This Follow-Up"
            }
        }

        switch action {
        case .saveForLater:
            return "Couldn’t Save & Start Follow-Up from “\(displayName)”"
        case .discard:
            return "Couldn’t Discard & Start Follow-Up from “\(displayName)”"
        }
    }

    func lifetimeWorkMetric(totalVolume: Double, totalBodyweightReps: Int) -> (title: String, value: String, subtitle: String) {
        let safeVolume = totalVolume.isFinite ? max(0, totalVolume) : 0
        let safeBodyweightReps = max(0, totalBodyweightReps)

        if safeVolume > 0 {
            return (
                title: "Volume",
                value: formatTotalVolume(safeVolume),
                subtitle: "lb lifted"
            )
        }

        if safeBodyweightReps > 0 {
            return (
                title: "Reps",
                value: "\(safeBodyweightReps)",
                subtitle: "bodyweight reps"
            )
        }

        return (
            title: "Volume",
            value: "0",
            subtitle: "lb lifted"
        )
    }

    func formatTotalVolume() -> String {
        guard let stats = userStats else { return "0" }
        return formatTotalVolume(stats.totalVolume)
    }

    private func formatTotalVolume(_ totalVolume: Double) -> String {
        let safeVolume = totalVolume.isFinite ? max(0, totalVolume) : 0
        let truncatedVolume = floor(safeVolume * 10) / 10

        if truncatedVolume >= 1_000_000 {
            let millions = truncatedVolume / 1_000_000
            let truncatedMillions = floor(millions * 10) / 10
            let isWholeMillions = truncatedMillions.truncatingRemainder(dividingBy: 1) == 0

            return isWholeMillions
                ? "\(Int(truncatedMillions))M"
                : String(format: "%.1fM", truncatedMillions)
        }

        if truncatedVolume >= 1000 {
            let thousands = truncatedVolume / 1000
            let truncatedThousands = floor(thousands * 10) / 10
            let isWholeThousands = truncatedThousands.truncatingRemainder(dividingBy: 1) == 0

            return isWholeThousands
                ? "\(Int(truncatedThousands))k"
                : String(format: "%.1fk", truncatedThousands)
        }

        return "\(Int(floor(truncatedVolume)))"
    }

    private func normalizedSummaryName(_ raw: String?) -> String? {
        guard let raw else { return nil }

        let collapsedName = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return nil
        }

        return String(collapsedName.prefix(80))
    }

    private func resumableWorkoutSourceTemplateName(for workout: Workout) -> String? {
        let resolvedTemplateName = templateManager
            .sourceTemplate(for: workout)
            .map(\.name)

        return normalizedSummaryName(resolvedTemplateName)
            ?? normalizedSummaryName(workout.startedFromTemplate)
    }

    private func hasFollowUpContent(in workout: Workout) -> Bool {
        workout.orderedExerciseGroups.contains { group in
            let workingSets = group.sets.filter(\.isCompletedWorkingSet)

            guard let firstWorkingSet = workingSets.first else {
                return false
            }

            return firstWorkingSet.weight > 0
                || (firstWorkingSet.weight == 0 && group.exercise.category == .bodyweight)
        }
    }
}
