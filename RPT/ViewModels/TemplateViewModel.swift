//
//  TemplateViewModel.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class TemplateViewModel: ObservableObject {
    private let templateManager: TemplateManager
    
    @Published var templates: [WorkoutTemplate] = []
    
    init(templateManager: TemplateManager? = nil) {
        self.templateManager = templateManager ?? TemplateManager.shared
        refreshTemplates()
    }
    
    func refreshTemplates() {
        templates = templateManager.fetchAllTemplates()
    }
    
    func fetchTemplates() -> [WorkoutTemplate] {
        refreshTemplates()
        return templates
    }
    
    func createTemplate(name: String, exercises: [TemplateExercise], notes: String = "") {
        _ = templateManager.createTemplate(name: name, exercises: exercises, notes: notes)
        refreshTemplates()
    }
    
    func updateTemplate(_ template: WorkoutTemplate, name: String, exercises: [TemplateExercise], notes: String) {
        templateManager.updateTemplate(template, name: name, exercises: exercises, notes: notes)
        refreshTemplates()
    }
    
    func deleteTemplate(_ template: WorkoutTemplate) {
        templateManager.deleteTemplate(template)
        refreshTemplates()
    }
    
    func createWorkoutFromTemplate(_ template: WorkoutTemplate) -> Workout {
        return templateManager.createWorkoutFromTemplate(template)
    }
    
    func addExerciseToTemplate(_ template: WorkoutTemplate, exerciseName: String) {
        templateManager.addExerciseToTemplate(template, exerciseName: exerciseName)
        refreshTemplates()
    }
    
    func updateTemplateExercise(_ template: WorkoutTemplate, exerciseId: UUID, updatedExercise: TemplateExercise) {
        templateManager.updateTemplateExercise(template, exerciseId: exerciseId, updatedExercise: updatedExercise)
        refreshTemplates()
    }
    
    func removeExerciseFromTemplate(_ template: WorkoutTemplate, exerciseId: UUID) {
        templateManager.removeExerciseFromTemplate(template, exerciseId: exerciseId)
        refreshTemplates()
    }
}
