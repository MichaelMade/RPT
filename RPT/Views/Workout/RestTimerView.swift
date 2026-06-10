//
//  RestTimerView.swift
//  RPT
//
//  Countdown between sets with a progress ring, quick ±15s adjustments,
//  and sound + haptic completion cues.
//

import SwiftUI

struct RestTimerView: View {
    @Environment(\.dismiss) private var dismiss

    let duration: Int

    @State private var remainingSeconds: Int = 0
    @State private var totalSeconds: Int = 0
    @State private var isPaused = false
    @State private var didComplete = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text(didComplete ? "Rest Complete" : "Rest Timer")
                .font(.headline)
                .foregroundStyle(didComplete ? Theme.success : .primary)

            ZStack {
                ProgressRing(
                    progress: progress,
                    lineWidth: 12,
                    tint: didComplete ? AnyShapeStyle(Theme.success) : AnyShapeStyle(Theme.brandGradient)
                )
                .frame(width: 180, height: 180)

                VStack(spacing: 2) {
                    Text(timeString)
                        .font(Theme.statFont(size: 44))
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    if !didComplete {
                        Text("of \(formatted(totalSeconds))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    adjust(by: -15)
                } label: {
                    Text("−15s")
                }
                .buttonStyle(SecondaryCapsuleButtonStyle())
                .disabled(didComplete)

                Button {
                    isPaused.toggle()
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .frame(width: 24)
                }
                .buttonStyle(SecondaryCapsuleButtonStyle())
                .disabled(didComplete)

                Button {
                    adjust(by: 15)
                } label: {
                    Text("+15s")
                }
                .buttonStyle(SecondaryCapsuleButtonStyle())
                .disabled(didComplete)
            }

            Button {
                dismiss()
            } label: {
                Text(didComplete ? "Back to Training" : "Skip Rest")
            }
            .buttonStyle(BrandButtonStyle())
            .padding(.horizontal, Theme.screenPadding)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.screenPadding)
        .onAppear {
            totalSeconds = max(1, duration)
            remainingSeconds = max(1, duration)
        }
        .onReceive(timer) { _ in
            tick()
        }
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1 - Double(remainingSeconds) / Double(totalSeconds)
    }

    private var timeString: String {
        formatted(remainingSeconds)
    }

    private func formatted(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }

    private func tick() {
        guard !isPaused, !didComplete else { return }

        if remainingSeconds <= 4 && remainingSeconds > 1 {
            HapticFeedbackManager.shared.timerCountdown()
        }

        if remainingSeconds > 0 {
            withAnimation {
                remainingSeconds -= 1
            }
        }

        if remainingSeconds <= 0 {
            didComplete = true
            HapticFeedbackManager.shared.timerComplete()
            SoundManager.shared.playTimerComplete()
        }
    }

    private func adjust(by delta: Int) {
        remainingSeconds = max(1, remainingSeconds + delta)
        totalSeconds = max(totalSeconds, remainingSeconds)
    }
}
