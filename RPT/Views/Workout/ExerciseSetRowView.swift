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
    let onUpdateDropSets: ((Double) -> Void)?
    // MARK: - End New Properties
    
    // Haptic feedback generator
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    let onUpdate: (Double, Int, Int?) -> Void
    let onDelete: () -> Void
    var onStartRestTimer: (() -> Void)? = nil // Optional rest timer callback
    
    // MARK: - Updated Initializer
    init(set: ExerciseSet,
         isFirstSet: Bool = false, // New parameter
         onUpdate: @escaping (Double, Int, Int?) -> Void,
         onDelete: @escaping () -> Void,
         onStartRestTimer: (() -> Void)? = nil,
         onUpdateDropSets: ((Double) -> Void)? = nil) { // New parameter
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
                                label: "-10",
                                action: { adjustWeight(by: -10) }
                            )
                        }
                        
                        // Weight input field
                        HStack {
                            TextField("Weight", text: $weightInput)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                                .frame(minWidth: 70)
                            
                            Text("lb")
                                .foregroundColor(.secondary)
                        }
                        
                        // Quick increase buttons
                        HStack(spacing: 0) {
                            QuickAdjustButton(
                                label: "+10",
                                action: { adjustWeight(by: 10) }
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
                    VStack(alignment: .leading, spacing: 6) {
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
                            
                            // Quick RPE buttons
                            HStack(spacing: 5) {
                                ForEach([7, 8, 9, 10], id: \.self) { value in
                                    Button("\(value)") {
                                        rpeInput = "\(value)"
                                        feedbackGenerator.impactOccurred(intensity: 0.5)
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                    .padding(.horizontal, 2)
                                    .padding(.vertical, 2)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                // Action buttons
                HStack {
                    Button("Cancel") {
                        isEditing = false
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Delete", role: .destructive) {
                        feedbackGenerator.impactOccurred(intensity: 0.7)
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save") {
                        saveSet()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            .onAppear {
                // Initialize haptic feedback
                feedbackGenerator.prepare()
                
                // Initialize text fields with current values
                weightInput = String(format: "%.1f", set.weight)
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
                        Text("\(set.weight, specifier: "%.1f") lb")
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
    
    private func adjustWeight(by amount: Double) {
        // Provide haptic feedback
        feedbackGenerator.impactOccurred(intensity: 0.6)
        
        // Parse current weight
        if let currentWeight = Double(weightInput) {
            let newWeight = max(0, currentWeight + amount)
            weightInput = String(format: "%.1f", newWeight)
        } else if amount > 0 {
            // If field is empty and we're increasing, start at the increment
            weightInput = String(format: "%.1f", abs(amount))
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
        if let weight = Double(weightInput), let reps = Int(repsInput) {
            let rpe = rpeInput.isEmpty ? nil : Int(rpeInput)
            
            // Validate inputs
            let validatedWeight = max(0, weight)
            let validatedReps = max(0, reps)
            let validatedRPE = rpe.map { min(10, max(1, $0)) }
            
            // Update the set
            onUpdate(validatedWeight, validatedReps, validatedRPE)
            
            // MARK: - Code for Drop Set Calculation
            // If this is the first set, update drop sets through callback
            if isFirstSet && validatedWeight > 0 && onUpdateDropSets != nil {
                onUpdateDropSets!(validatedWeight)
            }
            // MARK: - End New Code
            
            isEditing = false
            
            // Start rest timer if callback is available and set has weight
            if validatedWeight > 0, let startTimer = onStartRestTimer {
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
    let modelContainer = try! ModelContainer(for: ExerciseSet.self, Exercise.self)
    
    // Create an exercise
    let benchPress = Exercise(
        name: "Bench Press",
        category: .compound,
        primaryMuscleGroups: [.chest],
        secondaryMuscleGroups: [.triceps, .shoulders]
    )
    
    // Create a set
    let exerciseSet = ExerciseSet(
        weight: 225.0,
        reps: 6,
        exercise: benchPress
    )
    
    modelContainer.mainContext.insert(benchPress)
    modelContainer.mainContext.insert(exerciseSet)
    
    return VStack {
        // Regular set
        ExerciseSetRowView(
            set: exerciseSet,
            isFirstSet: false,
            onUpdate: { _, _, _ in },
            onDelete: {},
            onStartRestTimer: {},
            onUpdateDropSets: nil
        )
        .padding()
        .background(Color(.systemBackground))
        
        // First set with drop set calculation
        ExerciseSetRowView(
            set: exerciseSet,
            isFirstSet: true,
            onUpdate: { _, _, _ in },
            onDelete: {},
            onStartRestTimer: {},
            onUpdateDropSets: { _ in }
        )
        .padding()
        .background(Color(.systemBackground))
    }
    .modelContainer(modelContainer)
    .preferredColorScheme(.light)
}

// Preview in edit mode
#Preview("Editing Set") {
    let modelContainer = try! ModelContainer(for: ExerciseSet.self, Exercise.self)
    
    // Create an exercise
    let benchPress = Exercise(
        name: "Bench Press",
        category: .compound,
        primaryMuscleGroups: [.chest],
        secondaryMuscleGroups: [.triceps, .shoulders]
    )
    
    // Create a set
    let exerciseSet = ExerciseSet(
        weight: 225.0,
        reps: 6,
        exercise: benchPress
    )
    
    modelContainer.mainContext.insert(benchPress)
    modelContainer.mainContext.insert(exerciseSet)
    
    // This is a workaround to force the edit mode to be active in preview
    struct EditModeWrapper: View {
        @State private var isEditing = true
        var set: ExerciseSet
        
        var body: some View {
            if isEditing {
                ExerciseSetRowView(
                    set: set,
                    isFirstSet: true,
                    onUpdate: { _, _, _ in },
                    onDelete: {},
                    onStartRestTimer: {},
                    onUpdateDropSets: { _ in }
                )
                .onAppear {
                    // This forces edit mode in preview
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Hack to force edit mode in preview
                        // Note: This only works for actual preview, not for the code
                    }
                }
            }
        }
    }
    
    return EditModeWrapper(set: exerciseSet)
        .padding()
        .background(Color(.systemBackground))
        .modelContainer(modelContainer)
}
