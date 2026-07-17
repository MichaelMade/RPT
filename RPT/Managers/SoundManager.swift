//
//  SoundManager.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//
//  Plays short system-sound cues for training events. System sounds need
//  no bundled audio files and automatically respect the ringer switch.
//

import Foundation
import AudioToolbox

class SoundManager {
    static let shared = SoundManager()

    private var isEnabled = true

    enum SoundEffect {
        case timerStart
        case timerTick
        case timerComplete
        case success
        case buttonTap
        case addSet
        case completeWorkout

        /// Built-in system sound for each cue.
        var systemSoundID: SystemSoundID {
            switch self {
            case .timerStart, .timerTick:
                return 1057 // Tink — light tick
            case .timerComplete, .success:
                return 1322 // Bloom — calm chime
            case .buttonTap, .addSet:
                return 1104 // Tock — soft mechanical confirm
            case .completeWorkout:
                return 1025 // Fanfare — celebratory finish
            }
        }
    }

    private init() {
        // Sounds default to on; only an explicit user preference turns them off.
        if UserDefaults.standard.object(forKey: "sound_enabled") != nil {
            isEnabled = UserDefaults.standard.bool(forKey: "sound_enabled")
        }
    }

    // Enable/disable sound effects
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "sound_enabled")
    }

    // Check if sound is enabled
    func isSoundEnabled() -> Bool {
        return isEnabled
    }

    // Play a sound effect
    func play(_ effect: SoundEffect) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(effect.systemSoundID)
    }

    // Play timer completion sound with haptic feedback
    func playTimerComplete() {
        play(.timerComplete)
        HapticFeedbackManager.shared.timerComplete()
    }

    // Play timer tick sound for countdown
    func playTimerTick() {
        play(.timerTick)
    }

    // Play success sound with haptic feedback
    func playSuccess() {
        play(.success)
        HapticFeedbackManager.shared.success()
    }

    // Play button tap sound with light haptic feedback
    func playButtonTap() {
        play(.buttonTap)
        HapticFeedbackManager.shared.light()
    }

    // Play add set sound
    func playAddSet() {
        play(.addSet)
        HapticFeedbackManager.shared.medium()
    }

    // Complete workout sound and haptic
    func playWorkoutComplete() {
        play(.completeWorkout)
        HapticFeedbackManager.shared.success()
    }
}
