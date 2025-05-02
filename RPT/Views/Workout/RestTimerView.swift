//
//  RestTimerView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import Combine

struct RestTimerView: View {
    let defaultDuration: Int
    @Binding var isShowing: Bool
    
    @State private var timeRemaining: Int
    @State private var timer: Timer.TimerPublisher = Timer.publish(every: 1, on: .main, in: .common)
    @State private var timerConnector: Cancellable?
    @State private var isPaused = false
        
    init(defaultDuration: Int, isShowing: Binding<Bool>) {
        self.defaultDuration = defaultDuration
        self._isShowing = isShowing
        self._timeRemaining = State(initialValue: defaultDuration)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Title and close button
            HStack {
                Text("Rest Timer")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    stopTimer()
                    withAnimation {
                        isShowing = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            
            // Timer display
            ZStack {
                // Background circle
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.2)
                    .foregroundColor(.blue)
                
                // Progress circle
                Circle()
                    .trim(from: 0.0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                    .foregroundColor(timerColor)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: progress)
                
                // Time remaining
                VStack {
                    Text(timeFormatted)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(timerColor)
                    
                    Text("Seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            .padding()
            
            // Controls
            HStack(spacing: 40) {
                // Reset button
                Button {
                    resetTimer()
                } label: {
                    VStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                        Text("Reset")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                
                // Play/Pause button
                Button {
                    toggleTimer()
                } label: {
                    VStack {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title)
                        Text(isPaused ? "Resume" : "Pause")
                            .font(.caption)
                    }
                    .foregroundColor(isPaused ? .green : .orange)
                }
                
                // Skip button
                Button {
                    skipTimer()
                } label: {
                    VStack {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                        Text("Skip")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding(.vertical)
            
            // Quick time adjust buttons
            HStack {
                ForEach([30, 60, 90, 120, 180], id: \.self) { seconds in
                    Button("\(formatTimeButton(seconds))") {
                        setTime(seconds)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
            .padding(.bottom)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .frame(width: 300)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var timeFormatted: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%01d:%02d", minutes, seconds)
    }
    
    private func formatTimeButton(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            return "\(seconds/60)m"
        }
    }
    
    private var progress: CGFloat {
        if defaultDuration <= 0 { return 0 }
        return 1.0 - CGFloat(timeRemaining) / CGFloat(defaultDuration)
    }
    
    private var timerColor: Color {
        if timeRemaining > defaultDuration / 3 {
            return .blue
        } else if timeRemaining > defaultDuration / 6 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Timer Methods
    
    private func startTimer() {
        // Cancel any existing timer first to prevent duplicates
        stopTimer()
        
        timer = Timer.publish(every: 1, on: .main, in: .common)
        timerConnector = timer.connect()
        isPaused = false
        HapticFeedbackManager.shared.medium()
        
        // Create a new publisher and subscribe to it
        let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        let cancellable = timerPublisher.sink { _ in
            guard !isPaused else { return }
            
            if timeRemaining > 0 {
                timeRemaining -= 1
                
                // Play sound when almost done
                if timeRemaining <= 3 && timeRemaining > 0 {
                    HapticFeedbackManager.shared.medium()
                }
                
                // Handle timer completion
                if timeRemaining == 0 {
                    HapticFeedbackManager.shared.success()
                    
                    // Auto-close after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isShowing = false
                        }
                    }
                }
            }
        }
        
        // Store the cancellable
        timerCancellable.insert(cancellable)
    }
    
    private func stopTimer() {
        // Cancel the connector
        timerConnector?.cancel()
        timerConnector = nil
        
        // Cancel all timer subscriptions
        timerCancellable.forEach { $0.cancel() }
        timerCancellable.removeAll()
    }
    
    private func resetTimer() {
        timeRemaining = defaultDuration
        
        if isPaused {
            startTimer()
        }
    }
    
    private func toggleTimer() {
        isPaused.toggle()
        HapticFeedbackManager.shared.medium()
    }
    
    private func skipTimer() {
        // Stop the timer first
        if !isPaused {
            stopTimer()
        }
        
        timeRemaining = 0
        HapticFeedbackManager.shared.success()
        
        // Auto-close after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                isShowing = false
            }
        }
    }
    
    private func setTime(_ seconds: Int) {
        timeRemaining = seconds
        if isPaused {
            startTimer()
        }
        HapticFeedbackManager.shared.medium()
    }
    
    // Store cancellables
    @State private var timerCancellable = Set<AnyCancellable>()
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        RestTimerView(
            defaultDuration: 180,
            isShowing: .constant(true)
        )
    }
}
