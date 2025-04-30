//
//  HapticFeedbackManager.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import Foundation
import UIKit
import SwiftUI
import AVFoundation

// MARK: - Haptic Feedback Manager

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private init() {}
    
    // Simple impact feedback
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    // Light impact for minor interactions
    func light() {
        impact(style: .light)
    }
    
    // Medium impact for standard interactions
    func medium() {
        impact(style: .medium)
    }
    
    // Heavy impact for significant interactions
    func heavy() {
        impact(style: .heavy)
    }
    
    // Success notification
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Warning notification
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    // Error notification
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // Timer countdown (multiple vibrations)
    func timerCountdown() {
        // Multiple light impacts with delay
        impact(style: .light)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.impact(style: .light)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.impact(style: .medium)
        }
    }
    
    // Timer completion (stronger pattern)
    func timerComplete() {
        // Stronger pattern for timer completion
        impact(style: .medium)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.impact(style: .medium)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.impact(style: .heavy)
        }
    }
}

// MARK: - Button Style with Haptic Feedback

struct HapticButtonStyle: ButtonStyle {
    let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
    let soundEffect: SoundManager.SoundEffect?
    
    init(feedback: UIImpactFeedbackGenerator.FeedbackStyle = .light,
         sound: SoundManager.SoundEffect? = nil) {
        self.feedbackStyle = feedback
        self.soundEffect = sound
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedbackManager.shared.impact(style: feedbackStyle)
                    if let sound = soundEffect {
                        SoundManager.shared.play(sound)
                    }
                }
            }
    }
}

extension View {
    // Add haptic feedback to a button
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
                        sound: SoundManager.SoundEffect? = nil) -> some View {
        self.buttonStyle(HapticButtonStyle(feedback: style, sound: sound))
    }
}
