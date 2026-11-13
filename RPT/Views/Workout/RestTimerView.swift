//
//  RestTimerView.swift
//  RPT
//
//  Docked rest countdown that sits above the finish button instead of
//  blocking in a sheet: wall-clock countdown, +15s adjustment, skip, and
//  sound + haptic completion cues. Once RPT leaves the foreground those
//  cues cannot play, so an opt-in local notification stands in for them.
//

import Combine
import SwiftUI

struct RestTimerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var restAlerts = RestAlertManager.shared

    let duration: Int
    /// Called when the user skips the rest (or dismisses the finished timer).
    var onSkip: () -> Void = {}

    /// Wall-clock deadline the countdown runs toward. Ticks only repaint;
    /// time keeps passing while the app is suspended or the phone is locked.
    @State private var endDate: Date = .distantFuture
    @State private var remainingSeconds: Int = 0
    @State private var totalSeconds: Int = 0
    @State private var didComplete = false

    /// Decided once per rest so the offer does not vanish mid-countdown
    /// when its own display is counted.
    @State private var offersRestAlert = false
    @State private var showingRestAlertOffer = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        // The dock is dark in both modes (Theme.inverted), so its content is
        // deliberately white rather than themed text colors.
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.dropTwoForeground)

            Text(didComplete ? "Rest complete" : "Resting")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.75))
                .accessibilityLabel("Rest Timer")

            if offersRestAlert && !didComplete {
                Button {
                    showingRestAlertOffer = true
                } label: {
                    Image(systemName: "bell.badge")
                }
                .buttonStyle(RestChipButtonStyle())
                .accessibilityLabel("Alert me when rest ends")
                .accessibilityIdentifier("restAlertOffer")
            }

            Spacer(minLength: 8)

            Text(timeString)
                .font(Theme.statFont(size: 20))
                .monospacedDigit()
                .foregroundStyle(didComplete ? Theme.doneForeground : .white)
                .contentTransition(.numericText())
                .accessibilityLabel("Rest time remaining")
                .accessibilityValue(timeString)

            Button("+15s") {
                adjust(by: 15)
            }
            .buttonStyle(RestChipButtonStyle())
            .disabled(didComplete)
            .accessibilityLabel("Add 15 seconds of rest")

            Button("Skip") {
                onSkip()
            }
            .buttonStyle(RestChipButtonStyle())
            .accessibilityLabel("Skip Rest")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.inverted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            totalSeconds = max(1, duration)
            remainingSeconds = totalSeconds
            endDate = Date().addingTimeInterval(TimeInterval(totalSeconds))
        }
        .task {
            // The offer depends on what iOS has already been told, so read
            // that before deciding to show it.
            await restAlerts.refreshPermission()
            offersRestAlert = restAlerts.claimDockOffer()
        }
        .onReceive(timer) { _ in
            syncRemaining()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                // Locked or behind another app, the chime and haptics below
                // cannot play. Hand the end of rest to a notification. It
                // exists only while RPT is out of the foreground: this dock
                // cannot be skipped or restarted from there, and `.active`
                // below always takes it back first.
                if !didComplete {
                    restAlerts.scheduleRestEnd(at: endDate)
                }
            case .active:
                // Catch up immediately after returning from the background
                // so the countdown reflects the rest actually taken, then
                // take the alert back: in the foreground the dock owns it.
                syncRemaining()
                restAlerts.cancelRestEnd()
                Task { await restAlerts.refreshPermission() }
            default:
                break
            }
        }
        .alert("Alert when rest ends?", isPresented: $showingRestAlertOffer) {
            Button("Turn On") {
                offersRestAlert = false
                Task { await restAlerts.enable() }
            }
            Button("Not Now", role: .cancel) {
                offersRestAlert = false
                restAlerts.declineDockOffer()
            }
        } message: {
            Text("RPT can notify you when your rest is over, so you can lock your phone or switch apps between sets.")
        }
    }

    private var timeString: String {
        formatted(remainingSeconds)
    }

    private func formatted(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }

    private func syncRemaining(now: Date = Date()) {
        guard !didComplete else { return }

        let newRemaining = max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
        guard newRemaining != remainingSeconds else { return }

        withAnimation {
            remainingSeconds = newRemaining
        }

        if (1...3).contains(newRemaining) {
            HapticFeedbackManager.shared.timerCountdown()
        }

        if newRemaining <= 0 {
            didComplete = true

            // A rest that ended while RPT was in the background was already
            // announced by its notification. Chiming again on return would
            // be a second, late alert for the same event.
            if !restAlerts.scheduledAlertHasFired(asOf: now) {
                // playTimerComplete() owns both the chime and the completion haptic.
                SoundManager.shared.playTimerComplete()
            }
        }
    }

    private func adjust(by delta: Int) {
        remainingSeconds = max(1, remainingSeconds + delta)
        totalSeconds = max(totalSeconds, remainingSeconds)
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
    }
}

/// Small translucent chip button used inside the dark rest dock.
private struct RestChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Color.white.opacity(0.14),
                in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
