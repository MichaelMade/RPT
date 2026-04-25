//
//  RPTCalculatorView.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import SwiftUI

struct RPTCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultRPTPercentageDrops") private var savedPercentageDrops: Data = (try? JSONEncoder().encode(defaultPercentageDrops)) ?? Data()

    static let supportedSetCount = 3
    static let defaultPercentageDrops = [0.0, 0.10, 0.15]
    
    @State private var firstSetWeight = 225 // Default in pounds (integer)
    @State private var targetReps = [6, 8, 10]
    @State private var percentageDrops = defaultPercentageDrops
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("First Set")) {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $firstSetWeight, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: firstSetWeight) { _, newValue in
                                // Round to nearest 5
                                firstSetWeight = WorkoutManager.shared.roundToNearest5(Double(newValue))
                            }
                        Text("lb")
                    }
                    
                    HStack {
                        Text("Target Reps")
                        Spacer()
                        TextField("Reps", value: $targetReps[0], format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }
                }
                
                // Sets display
                Section(header: Text("RPT Sets")) {
                    ForEach(0..<3) { index in
                        HStack {
                            Text("Set \(index + 1)")
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(calculateWeight(for: index)) lb × \(targetReps[safe: index] ?? 0)")
                                .fontWeight(index == 0 ? .bold : .regular)
                        }
                    }
                }
                
                // Customize percentages
                Section(header: Text("Weight Reductions")) {
                    ForEach(1..<3) { index in
                        HStack {
                            Text("Set \(index + 1)")
                            Spacer()
                            Text("-")
                            TextField("", value: Binding(
                                get: { Int(percentageDrops[index] * 100) },
                                set: {
                                    percentageDrops = Self.updatedPercentageDrops(
                                        percentageDrops,
                                        editing: index,
                                        rawPercent: $0
                                    )
                                }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            Text("%")
                        }
                    }
                }
                
                // RPT explanation
                Section(header: Text("How RPT Works")) {
                    Text("Reverse Pyramid Training starts with your heaviest set first, then reduces weight and increases reps for subsequent sets.")
                    
                    Text("This maximizes strength gains by prioritizing heavy lifting when you're fresh, while still getting volume with the lighter follow-up sets.")
                }
            }
            .navigationTitle("RPT Calculator")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Save percentage drops for future use
                        percentageDrops = Self.normalizedPercentageDrops(percentageDrops)

                        do {
                            savedPercentageDrops = try JSONEncoder().encode(percentageDrops)
                        } catch {
                            print("Failed to save percentage drops: \(error)")
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Load saved percentage drops
                do {
                    let loadedDrops = try JSONDecoder().decode([Double].self, from: savedPercentageDrops)
                    percentageDrops = Self.normalizedPercentageDrops(loadedDrops)
                } catch {
                    percentageDrops = Self.normalizedPercentageDrops([])
                    print("Failed to load percentage drops: \(error)")
                }
            }
        }
    }

    static func normalizedPercentageDrops(_ drops: [Double]) -> [Double] {
        let normalizedDrops = Array(UserSettings.normalizedRPTPercentageDrops(drops).prefix(supportedSetCount))

        if normalizedDrops.count == supportedSetCount {
            return normalizedDrops
        }

        var fixedDrops = normalizedDrops
        while fixedDrops.count < supportedSetCount {
            fixedDrops.append(defaultPercentageDrops[fixedDrops.count])
        }

        return fixedDrops
    }

    static func updatedPercentageDrops(_ drops: [Double], editing index: Int, rawPercent: Int) -> [Double] {
        var updatedDrops = normalizedPercentageDrops(drops)

        guard updatedDrops.indices.contains(index) else {
            return updatedDrops
        }

        let boundedPercentage = min(max(rawPercent, 0), 100)
        updatedDrops[index] = Double(boundedPercentage) / 100.0
        updatedDrops[0] = 0.0

        guard updatedDrops.count > 1 else {
            return updatedDrops
        }

        for dropIndex in 1..<updatedDrops.count where updatedDrops[dropIndex] < updatedDrops[dropIndex - 1] {
            updatedDrops[dropIndex] = updatedDrops[dropIndex - 1]
        }

        return updatedDrops
    }
    
    private func calculateWeight(for setIndex: Int) -> Int {
        guard setIndex < percentageDrops.count else { return 0 }
        let calculatedWeight = Double(firstSetWeight) * (1 - percentageDrops[setIndex])
        return WorkoutManager.shared.roundToNearest5(calculatedWeight)
    }
}

#Preview {
    // Create a preview with some realistic data
    RPTCalculatorView()
}
