//
//  SettingsView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                // General Settings Section
                Section(header: Text("General")) {
                    Picker("Dark Mode", selection: $viewModel.darkModePreference) {
                        Text("Light").tag(DarkModePreference.light)
                        Text("Dark").tag(DarkModePreference.dark)
                        Text("System").tag(DarkModePreference.system)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Workout Options Section
                Section(header: Text("Workout Options")) {
                    Toggle("Show RPE Input", isOn: $viewModel.showRPE)
                    
                    Stepper(
                        "Rest Timer: \(viewModel.restTimerDuration) seconds",
                        value: $viewModel.restTimerDuration,
                        in: 30...300,
                        step: 15
                    )
                }
                
                // Reverse Pyramid Training Section
                Section(header: Text("Reverse Pyramid Training")) {
                    Text("Default Weight Reductions")
                        .font(.headline)
                        .padding(.vertical, 4)
                    
                    ForEach(0..<min(3, viewModel.defaultRPTPercentageDrops.count), id: \.self) { index in
                        if index == 0 {
                            Text("First Set: 100%")
                        } else {
                            let binding = Binding<Double>(
                                get: {
                                    viewModel.defaultRPTPercentageDrops[index] * 100
                                },
                                set: { newValue in
                                    var newDrops = viewModel.defaultRPTPercentageDrops
                                    newDrops[index] = newValue / 100
                                    viewModel.defaultRPTPercentageDrops = newDrops
                                }
                            )
                            
                            HStack {
                                Text("Set \(index + 1):")
                                Spacer()
                                Slider(value: binding, in: 0...30, step: 5) {
                                    Text("Set \(index + 1)")
                                } minimumValueLabel: {
                                    Text("0%")
                                } maximumValueLabel: {
                                    Text("30%")
                                }
                                .frame(width: 200)
                                Text("\(Int(binding.wrappedValue))%")
                                    .frame(width: 40)
                            }
                        }
                    }
                    
                    Text("Example: For a first set of 225 lb, subsequent sets would be \(viewModel.calculateExample(firstWeight: 225)) lb")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                NavigationLink {
                    AboutView()
                } label: {
                    Text("About RPT Trainer")
                }
                
                Button("Reset to Defaults") {
                    showingResetConfirmation = true
                }
                .foregroundColor(.red)
                
                // App Info Section
                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(viewModel.getAppVersion())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset Settings", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    viewModel.resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values. This cannot be undone.")
            }
        }
    }
}
