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
    @State private var timerDuration: Int
    @State private var isPaused = false
    @State private var timerCancellable = Set<AnyCancellable>()
    @State private var dismissWorkItem: DispatchWorkItem?

    enum TimerPhase: Equatable {
        case normal
        case warning
        case critical
    }

    init(defaultDuration: Int, isShowing: Binding<Bool>) {
        self.defaultDuration = defaultDuration
        self._isShowing = isShowing
        let safeDefaultDuration = max(defaultDuration, 0)
        self._timeRemaining = State(initialValue: safeDefaultDuration)
        self._timerDuration = State(initialValue: safeDefaultDuration)
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
        Self.normalizedProgress(timeRemaining: timeRemaining, duration: timerDuration)
    }

    private var timerColor: Color {
        switch Self.phase(forTimeRemaining: timeRemaining, duration: timerDuration) {
        case .normal:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }

    static func normalizedProgress(timeRemaining: Int, duration: Int) -> CGFloat {
        guard duration > 0 else { return 0 }

        let clampedRemaining = min(max(timeRemaining, 0), duration)
        return 1.0 - CGFloat(clampedRemaining) / CGFloat(duration)
    }

    static func phase(forTimeRemaining timeRemaining: Int, duration: Int) -> TimerPhase {
        guard duration > 0 else { return .critical }

        let clampedRemaining = max(timeRemaining, 0)
        let warningThreshold = max(1, Int(ceil(Double(duration) / 3.0)))
        let criticalThreshold = max(1, Int(ceil(Double(duration) / 6.0)))

        if clampedRemaining > warningThreshold {
            return .normal
        } else if clampedRemaining > criticalThreshold {
            return .warning
        } else {
            return .critical
        }
    }
    
    // MARK: - Timer Methods
    
    private func startTimer() {
        stopTimer()

        let safeDuration = max(timerDuration, 0)
        timerDuration = safeDuration
        timeRemaining = min(max(timeRemaining, 0), safeDuration)

        guard safeDuration > 0 else {
            timeRemaining = 0
            isPaused = true
            scheduleDismiss(after: 0.2)
            return
        }

        isPaused = false
        HapticFeedbackManager.shared.medium()

        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                tick()
            }
            .store(in: &timerCancellable)
    }

    private func tick() {
        guard !isPaused, timeRemaining > 0 else { return }

        timeRemaining -= 1

        if timeRemaining <= 3 && timeRemaining > 0 {
            HapticFeedbackManager.shared.medium()
        }

        if timeRemaining == 0 {
            HapticFeedbackManager.shared.success()
            scheduleDismiss(after: 2)
        }
    }

    private func stopTimer() {
        timerCancellable.forEach { $0.cancel() }
        timerCancellable.removeAll()
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
    }
    
    private func resetTimer() {
        let safeDefaultDuration = max(defaultDuration, 0)
        timerDuration = safeDefaultDuration
        timeRemaining = safeDefaultDuration
        
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
        scheduleDismiss(after: 1)
    }

    private func scheduleDismiss(after delay: TimeInterval) {
        dismissWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            withAnimation {
                isShowing = false
            }
        }

        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    private func setTime(_ seconds: Int) {
        let safeSeconds = max(seconds, 0)
        timerDuration = safeSeconds
        timeRemaining = safeSeconds

        if isPaused {
            startTimer()
        }
        HapticFeedbackManager.shared.medium()
    }
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
