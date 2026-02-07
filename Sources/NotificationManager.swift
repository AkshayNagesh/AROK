//
//  NotificationManager.swift
//  AROK
//
//  Purpose: Manages snarky, helpful user notifications
//  Created: 2026-02-07
//
//  Provides personality to AROK through witty, self-aware notifications that explain
//  what actions were taken and why. Uses randomized message selection to feel more
//  human and less robotic. All messages are clean and professional while still being
//  memorable and engaging.
//

import Foundation
import os.log

/// Manages user notifications with personality
///
/// NotificationManager provides a clean interface for generating context-aware notification
/// messages with varying tone and style. Messages are randomly selected from curated banks
/// to prevent repetition and maintain user engagement.
///
/// Design philosophy:
/// - Helpful first, snarky second
/// - Self-aware humor ("I know I'm just an app...")
/// - Emphasize the value provided ("I just saved you from a freeze")
/// - Never offensive or unprofessional
///
/// Example usage:
/// ```swift
/// let message = NotificationManager.getSnarkMessage(
///     type: .autoSuspend(count: 3, ramFreed: 2.5)
/// )
/// // Returns: "Yikes! RAM hit 85%. I just benched 3 lazy processes for you."
/// ```
///
/// Threading: Thread-safe (stateless struct)
/// State: Stateless - can be called from any context
///
/// - Note: Uses .randomElement() with fallbacks to prevent crashes
/// - Note: All messages logged for debugging notification issues
struct NotificationManager {
    private static let logger = Logger(subsystem: "com.arok.app", category: "Notifications")

    /// Types of notifications that can be triggered
    enum NotificationType {
        /// Auto-suspend triggered by RAM threshold
        case autoSuspend(count: Int, ramFreed: Double)
        /// User manually suspended a process
        case manualSuspend(processName: String)
        /// User resumed a suspended process
        case resume(processName: String)
        /// AI-driven predictive action taken
        case predictive(action: String)
        /// Browser tabs were suspended
        case tabsSuspended(count: Int, ramFreed: Double)
    }

    /// Generates a snarky notification message for the given event type
    ///
    /// Messages are randomly selected from pre-written banks to provide variety.
    /// Each notification is logged for debugging and analytics.
    ///
    /// - Parameter type: The type of event that occurred
    /// - Returns: Human-readable notification message
    ///
    /// Example:
    /// ```swift
    /// let msg = NotificationManager.getSnarkMessage(type: .autoSuspend(count: 2, ramFreed: 1.5))
    /// // Might return: "Close call! Suspended 2 apps before your Mac froze. You're welcome."
    /// ```
    static func getSnarkMessage(type: NotificationType) -> String {
        let message: String

        switch type {
        case .autoSuspend(let count, let ramFreed):
            message = autoSuspendMessages(count: count, ramFreed: ramFreed).randomElement() ?? "Auto-suspended \(count) processes"
            logger.info("🔔 Auto-suspend notification: \(message)")

        case .manualSuspend(let processName):
            message = manualSuspendMessages(processName: processName).randomElement() ?? "\(processName) suspended"
            logger.info("🔔 Manual suspend notification: \(message)")

        case .resume(let processName):
            message = resumeMessages(processName: processName).randomElement() ?? "\(processName) resumed"
            logger.info("🔔 Resume notification: \(message)")

        case .predictive(let action):
            message = predictiveMessages(action: action).randomElement() ?? "Proactive action: \(action)"
            logger.info("🔔 Predictive notification: \(message)")

        case .tabsSuspended(let count, let ramFreed):
            message = tabSuspendMessages(count: count, ramFreed: ramFreed).randomElement() ?? "Suspended \(count) tabs"
            logger.info("🔔 Tab suspend notification: \(message)")
        }

        return message
    }

    // MARK: - Message Banks

    /// Messages for auto-suspend events (RAM > 85%)
    ///
    /// Tone: Urgent but reassuring. Emphasizes that a freeze was prevented.
    /// Variables: count (number of processes), ramFreed (GB freed)
    private static func autoSuspendMessages(count: Int, ramFreed: Double) -> [String] {
        let ramStr = String(format: "%.1f", ramFreed)
        return [
            "Yikes! RAM hit 85%. I just benched \(count) lazy processes for you.",
            "Close call! Suspended \(count) apps before your Mac froze. You're welcome.",
            "Your Mac was about to beach ball. Crisis averted - suspended \(count) apps.",
            "RAM: 87% → \(Int(87 - ramFreed * 10))%. That was close. \(count) processes are napping now.",
            "Prevented a freeze by suspending \(count) apps. Freed up \(ramStr)GB.",
            "Auto-pilot engaged: \(count) processes suspended, \(ramStr)GB freed. Freeze avoided."
        ]
    }

    /// Messages for manual suspend actions
    ///
    /// Tone: Affirming and supportive. Validates user's decision.
    /// Variables: processName
    private static func manualSuspendMessages(processName: String) -> [String] {
        return [
            "\(processName) is taking a break. Your Mac thanks you.",
            "\(processName) suspended. More RAM for the important stuff.",
            "Put \(processName) to sleep. Wake it up when you need it.",
            "\(processName) is napping. Your Mac can breathe again.",
            "Suspended \(processName). Focus mode activated."
        ]
    }

    /// Messages for resume actions
    ///
    /// Tone: Slightly playful, welcoming process back.
    /// Variables: processName
    private static func resumeMessages(processName: String) -> [String] {
        return [
            "Welcome back, \(processName). Try not to hog all the RAM this time.",
            "\(processName) is awake and ready to work.",
            "Resumed \(processName). Let's see how long it stays well-behaved.",
            "\(processName) is back in action.",
            "Woke up \(processName). Keep an eye on it."
        ]
    }

    /// Messages for AI predictive actions
    ///
    /// Tone: Intelligent and proactive. Emphasizes pattern recognition.
    /// Variables: action (description of what was done)
    private static func predictiveMessages(action: String) -> [String] {
        return [
            "Heads up: Your Mac usually chokes around now. Pre-emptively freed 3GB.",
            "Pattern detected: You always run out of RAM at this time. Not today, friend.",
            "AI prediction: Build incoming. Pre-suspended media apps so you don't rage-quit later.",
            "Your Mac's fortune: I see a freeze in your future... but I prevented it.",
            "Proactive mode: \(action). Because I'm one step ahead."
        ]
    }

    /// Messages for browser tab suspension
    ///
    /// Tone: Slightly judgmental but helpful. Addresses tab hoarding habit.
    /// Variables: count (number of tabs), ramFreed (GB freed)
    private static func tabSuspendMessages(count: Int, ramFreed: Double) -> [String] {
        let ramStr = String(format: "%.1f", ramFreed)
        return [
            "Suspended \(count) browser tabs. Freed \(ramStr)GB. Do you really need 50 tabs open?",
            "Your \(count) Chrome tabs were using \(ramStr)GB. They're napping now.",
            "Closed \(count) tabs you forgot about. Freed \(ramStr)GB. You're welcome.",
            "Tab hoarder alert: Suspended \(count) tabs, saved \(ramStr)GB.",
            "\(count) tabs suspended. Your browser addiction is under control... for now."
        ]
    }
}
