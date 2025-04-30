//
//  SoundManager.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    private var audioPlayers: [URL: AVAudioPlayer] = [:]
    private var isEnabled = true
    
    enum SoundEffect: String {
        case timerStart = "timer_start.mp3"
        case timerTick = "timer_tick.mp3"
        case timerComplete = "timer_complete.mp3"
        case success = "success.mp3"
        case buttonTap = "button_tap.mp3"
        case addSet = "add_set.mp3"
        case completeWorkout = "complete_workout.mp3"
    }
    
    private init() {
        // Set up audio session
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        // Load preferences
        isEnabled = UserDefaults.standard.bool(forKey: "sound_enabled")
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
        
        let fileName = effect.rawValue
        guard let url = Bundle.main.url(forResource: fileName.components(separatedBy: ".").first,
                                       withExtension: fileName.components(separatedBy: ".").last) else {
            print("Sound file not found: \(fileName)")
            return
        }
        
        // Reuse audio player if possible
        if let player = audioPlayers[url] {
            player.currentTime = 0
            player.play()
            return
        }
        
        // Create new audio player
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayers[url] = player
            player.play()
        } catch {
            print("Failed to play sound: \(error.localizedDescription)")
        }
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
