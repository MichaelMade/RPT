//
//  ExerciseSetRowView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct ExerciseSetRowView: View {
    @Bindable var set: ExerciseSet
    @State private var isEditing = false
    @State private var weightInput = ""
    @State private var repsInput = ""
    @State private var rpeInput = ""
    @AppStorage("showRPE") private var showRPE = true
    
    // MARK: - New Properties
    // New property to track if this is the first set
    let isFirstSet: Bool
    // New callback for updating drop sets
    let onUpdateDropSets: ((Int) -> Void)?
    // MARK: - End New Properties
    
    // Haptic feedback generator
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    let onUpdate: (Int, Int, Int?) -> Void
    let onDelete: () -> Void
    var onStartRestTimer: (() -> Void)? = nil // Optional rest timer callback
    
    // MARK: - Updated Initializer
    init(set: ExerciseSet,
         isFirstSet: Bool = false, // New parameter
         onUpdate: @escaping (Int, Int, Int?) -> Void,
         onDelete: @escaping () -> Void,
         onStartRestTimer: (() -> Void)? = nil,
         onUpdateDropSets: ((Int) -> Void)? = nil) { // New parameter
        self.set = set
        self.isFirstSet = isFirstSet
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onStartRestTimer = onStartRestTimer
        self.onUpdateDropSets = onUpdateDropSets
    }
    // MARK: - End Updated Initializer
    
    var body: some View {
        if isEditing {
            VStack(spacing: 12) {
                // Weight input with quick adjust buttons
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        // Quick decrease buttons
                        HStack(spacing: 0) {
                            QuickAdjustButton(
                                label: "-5",
                                action: { adjustWeight(by: -5) }
                            )
                        }
                        
                        // Weight input field
                        HStack {
                            TextField("Weight", text: $weightInput)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                                .frame(minWidth: 70)
                            
                            Text("lb")
                                .foregroundColor(.secondary)
                        }
                        
                        // Quick increase buttons
                        HStack(spacing: 0) {
                            QuickAdjustButton(
                                label: "+5",
                                action: { adjustWeight(by: 5) }
                            )
                        }
                    }
                }
                
                // Reps input with quick adjust buttons
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        // Quick decrease buttons
                        HStack(spacing: 0) {
                            QuickAdjustButton(
                                label: "-1",
                                action: { adjustReps(by: -1) }
                            )
                        }
                        
                        // Reps input field
                        TextField("Reps", text: $repsInput)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                            .frame(width: 60)
                        
                        // Quick increase buttons
                        HStack(spacing: 0) {
                            QuickAdjustButton(
                                label: "+1",
                                action: { adjustReps(by: 1) }
                            )
                        }
                    }
                }
                
                // RPE input (optional)
                if showRPE {
                    VStack(alignment: .center, spacing: 6) {
                        Text("RPE (1-10)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            // RPE input field
                            TextField("Optional", text: $rpeInput)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 80)
                        }
                    }
                }
                
                
                // Action buttons
                HStack(spacing: 15) {
                    Button("Cancel") {
                        isEditing = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Delete", role: .destructive) {
                        feedbackGenerator.impactOccurred(intensity: 0.7)
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveSet()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(height: 50)
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            .onAppear {
                // Initialize haptic feedback
                feedbackGenerator.prepare()
                
                // Initialize text fields with current values
                weightInput = "\(set.weight)"
                repsInput = "\(set.reps)"
                
                if let rpe = set.rpe {
                    rpeInput = "\(rpe)"
                } else {
                    rpeInput = ""
                }
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(set.weight) lb")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("×")
                            .font(.headline)
                        
                        Text("\(set.reps) reps")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    
                    if let rpe = set.rpe {
                        Text("RPE: \(rpe)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    feedbackGenerator.impactOccurred(intensity: 0.4)
                    isEditing = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                feedbackGenerator.impactOccurred(intensity: 0.4)
                isEditing = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func adjustWeight(by amount: Int) {
        // Provide haptic feedback
        feedbackGenerator.impactOccurred(intensity: 0.6)
        
        // Parse current weight
        if let currentWeight = Int(weightInput) {
            let newWeight = max(0, currentWeight + amount)
            // Round to nearest 5
            let roundedWeight = WorkoutManager.shared.roundToNearest5(Double(newWeight))
            weightInput = "\(roundedWeight)"
        } else if amount > 0 {
            // If field is empty and we're increasing, start at the increment
            let roundedAmount = WorkoutManager.shared.roundToNearest5(Double(abs(amount)))
            weightInput = "\(roundedAmount)"
        }
    }
    
    private func adjustReps(by amount: Int) {
        // Provide haptic feedback
        feedbackGenerator.impactOccurred(intensity: 0.6)
        
        // Parse current reps
        if let currentReps = Int(repsInput) {
            let newReps = max(0, currentReps + amount)
            repsInput = "\(newReps)"
        } else if amount > 0 {
            // If field is empty and we're increasing, start at the increment
            repsInput = "\(abs(amount))"
        }
    }
    
    // MARK: - Modified saveSet method
    private func saveSet() {
        // Provide haptic feedback
        feedbackGenerator.impactOccurred(intensity: 0.7)
        
        // Convert inputs to appropriate types
        if let weightInput = Int(weightInput), let reps = Int(repsInput) {
            let rpe = rpeInput.isEmpty ? nil : Int(rpeInput)
            
            // Validate inputs
            let weight = WorkoutManager.shared.roundToNearest5(Double(max(0, weightInput)))
            let validatedReps = max(0, reps)
            let validatedRPE = rpe.map { min(10, max(1, $0)) }
            
            // Update the set
            onUpdate(weight, validatedReps, validatedRPE)
            
            // MARK: - Code for Drop Set Calculation
            // If this is the first set, update drop sets through callback
            if isFirstSet && weight > 0 && onUpdateDropSets != nil {
                onUpdateDropSets!(weight)
            }
            // MARK: - End New Code
            
            isEditing = false
            
            // Start rest timer if callback is available and set has weight
            if weight > 0, let startTimer = onStartRestTimer {
                // Small delay to allow the keyboard to dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startTimer()
                }
            }
        }
    }
    
    // MARK: - Quick Adjust Button Component
    
    struct QuickAdjustButton: View {
        let label: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    // Create a model container for preview
    let modelContainer = try! ModelContainer(for: ExerciseSet.self, Exercise.self)
    
    // Create a sample exercise and set
    let exercise = Exercise(
        name: "Bench Press",
        category: .compound,
        primaryMuscleGroups: [.chest],
        secondaryMuscleGroups: [.triceps, .shoulders]
    )
    
    let set = ExerciseSet(
        weight: 225,
        reps: 8,
        exercise: exercise
    )
    
    return VStack(spacing: 20) {
        // Normal set view
        ExerciseSetRowView(
            set: set,
            isFirstSet: true,
            onUpdate: { _, _, _ in },
            onDelete: { }
        )
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        
        // Another set with edit mode on initially
        let editSet = ExerciseSet(
            weight: 200,
            reps: 10,
            exercise: exercise,
            rpe: 8
        )
        
        ExerciseSetRowView(
            set: editSet,
            onUpdate: { _, _, _ in },
            onDelete: { }
        )
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .onAppear {
            // This doesn't actually work in preview, but shows the editing UI
            // for demonstration purposes
        }
    }
    .padding()
    .modelContainer(modelContainer)
}
