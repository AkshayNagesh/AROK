//
//  ActivityLogger.swift
//  AROK
//
//  Purpose: Logs user activity patterns for AI-powered predictive analysis
//  Created: 2026-02-07
//
//  Records system state periodically (RAM, CPU, active mode, processes) to build
//  historical data for pattern recognition. Claude AI analyzes these logs to predict
//  future freezes and recommend proactive actions.
//

import Foundation
import os.log

/// Manages activity logging for predictive AI analysis
///
/// ActivityLogger records system state every 5 minutes to build up historical data.
/// Logs are stored as line-delimited JSON for easy parsing and analysis by Claude AI.
///
/// On first launch, generates 3 days of realistic seed data showing clear patterns
/// (e.g., RAM spikes weekdays at 2-3pm) for impressive AI predictions in demos.
///
/// Example usage:
/// ```swift
/// // Log current state
/// ActivityLogger.shared.logActivity(
///     ramUsage: 87,
///     cpuUsage: 65.5,
///     activeMode: "build",
///     activeWindow: "VS Code - server.js",
///     topProcesses: ["Docker", "node", "Chrome"],
///     events: ["Auto-suspended Spotify"]
/// )
///
/// // Get logs for AI analysis
/// let logs = ActivityLogger.shared.getRecentLogs(days: 3)
/// // Feed to Claude AI...
/// ```
///
/// Threading: Thread-safe (synchronous file I/O)
/// File location: ~/Library/Application Support/AROK/activity.log
///
/// - Note: Automatically generates seed data on first launch
/// - Note: Each log entry is one line of JSON
class ActivityLogger {
    static let shared = ActivityLogger()
    private let logger = Logger(subsystem: "com.arok.app", category: "ActivityLogger")

    /// File URL for activity log
    private let logFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let arokDir = appSupport.appendingPathComponent("AROK")
        try? FileManager.default.createDirectory(at: arokDir, withIntermediateDirectories: true)
        return arokDir.appendingPathComponent("activity.log")
    }()

    private init() {
        // Create seed data if file doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            generateSeedData()
        }
        logger.info("✅ ActivityLogger initialized: \(self.logFileURL.path)")
    }

    // MARK: - Logging

    /// Records a snapshot of current system activity
    ///
    /// Appends one line of JSON to activity.log. Called periodically (every 5 min)
    /// by AppState to build up historical data for pattern analysis.
    ///
    /// - Parameters:
    ///   - ramUsage: Current RAM percentage (0-100)
    ///   - cpuUsage: Current CPU percentage
    ///   - activeMode: Current user mode (build/chill/focus)
    ///   - activeWindow: Title of frontmost window
    ///   - topProcesses: Names of heaviest processes
    ///   - events: Significant events (e.g., auto-suspend actions)
    ///
    /// Example:
    /// ```swift
    /// ActivityLogger.shared.logActivity(
    ///     ramUsage: 82,
    ///     cpuUsage: 55.3,
    ///     activeMode: "build",
    ///     activeWindow: "Terminal - npm run build",
    ///     topProcesses: ["Docker", "node", "Chrome"],
    ///     events: []
    /// )
    /// ```
    func logActivity(
        ramUsage: Int,
        cpuUsage: Double,
        activeMode: String,
        activeWindow: String,
        topProcesses: [String],
        events: [String]
    ) {
        let entry = ActivityLogEntry(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            ramUsage: ramUsage,
            cpuUsage: cpuUsage,
            activeMode: activeMode,
            activeWindow: activeWindow,
            topProcesses: topProcesses,
            events: events
        )

        do {
            let encoder = JSONEncoder()
            var jsonString = try String(data: encoder.encode(entry), encoding: .utf8) ?? ""
            jsonString += "\n"  // One entry per line

            // Append to existing file or create new
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(jsonString.data(using: .utf8) ?? Data())
                handle.closeFile()
            } else {
                // File doesn't exist yet, create it
                try jsonString.write(to: logFileURL, atomically: true, encoding: .utf8)
            }

            logger.debug("📝 Logged activity: RAM=\(ramUsage)%, CPU=\(cpuUsage)%")
        } catch {
            logger.error("❌ Failed to log activity: \(error.localizedDescription)")
        }
    }

    /// Retrieves recent activity logs for AI analysis
    ///
    /// Returns line-delimited JSON strings for the specified time period.
    /// Filters out entries older than the cutoff date.
    ///
    /// - Parameter days: Number of days of history to retrieve (default: 3)
    /// - Returns: String with one JSON object per line
    ///
    /// Example:
    /// ```swift
    /// let logs = ActivityLogger.shared.getRecentLogs(days: 3)
    /// // Returns: Multi-line string, each line is a JSON object
    /// // Feed directly to Claude API for analysis
    /// ```
    func getRecentLogs(days: Int = 3) -> String {
        do {
            let content = try String(contentsOf: logFileURL, encoding: .utf8)
            let lines = content.components(separatedBy: "\n")

            // Calculate cutoff date (N days ago)
            let cutoffDate = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))
            let formatter = ISO8601DateFormatter()

            // Filter to recent entries only
            let recentLines = lines.filter { line in
                guard !line.isEmpty,
                      let data = line.data(using: .utf8),
                      let entry = try? JSONDecoder().decode(ActivityLogEntry.self, from: data),
                      let date = formatter.date(from: entry.timestamp) else {
                    return false
                }
                return date > cutoffDate
            }

            logger.info("📊 Retrieved \(recentLines.count) log entries from last \(days) days")
            return recentLines.joined(separator: "\n")
        } catch {
            logger.error("❌ Failed to read activity logs: \(error.localizedDescription)")
            return ""
        }
    }

    // MARK: - Seed Data Generation

    /// Generates 3 days of realistic activity data for demo purposes
    ///
    /// Creates clear patterns that Claude AI can easily identify:
    /// - Morning (9am-12pm): Light usage, 50-65% RAM
    /// - Afternoon (2-3pm): Heavy builds, 82-90% RAM, frequent auto-suspends
    /// - Evening (7-9pm): Chill mode, 40-55% RAM, media apps
    ///
    /// This makes the AI prediction demo impressive immediately without waiting
    /// for real usage data to accumulate.
    private func generateSeedData() {
        logger.info("🌱 Generating seed activity data...")

        var seedEntries: [String] = []

        // Generate 3 days of realistic patterns
        let now = Date()
        let dayInSeconds: TimeInterval = 24 * 60 * 60

        for dayOffset in (0...2).reversed() {
            let date = now.addingTimeInterval(-Double(dayOffset) * dayInSeconds)

            // Morning pattern (9am-12pm): Light usage
            for hour in 9...11 {
                for minute in [0, 30] {
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
                    components.hour = hour
                    components.minute = minute
                    guard let timestamp = Calendar.current.date(from: components) else { continue }

                    let entry = ActivityLogEntry(
                        timestamp: ISO8601DateFormatter().string(from: timestamp),
                        ramUsage: Int.random(in: 50...65),
                        cpuUsage: Double.random(in: 20...35),
                        activeMode: "build",
                        activeWindow: "VS Code - main.swift",
                        topProcesses: ["VS Code", "Chrome", "Terminal"],
                        events: []
                    )
                    if let json = try? String(data: JSONEncoder().encode(entry), encoding: .utf8) {
                        seedEntries.append(json)
                    }
                }
            }

            // Afternoon pattern (2pm-3pm): HEAVY USAGE - Consistent pattern for AI to detect
            for hour in 14...15 {
                for minute in [0, 5, 10, 15, 20, 25, 30] {
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
                    components.hour = hour
                    components.minute = minute
                    guard let timestamp = Calendar.current.date(from: components) else { continue }

                    let ramUsage = Int.random(in: 82...90)
                    // Add suspension events when RAM is high (makes pattern obvious)
                    let events: [String] = ramUsage > 85 ? ["Auto-suspended Spotify", "Auto-suspended Chrome tabs"] : []

                    let entry = ActivityLogEntry(
                        timestamp: ISO8601DateFormatter().string(from: timestamp),
                        ramUsage: ramUsage,
                        cpuUsage: Double.random(in: 55...75),
                        activeMode: "build",
                        activeWindow: "Terminal - docker compose up",
                        topProcesses: ["Docker", "node", "Chrome", "postgres"],
                        events: events
                    )
                    if let json = try? String(data: JSONEncoder().encode(entry), encoding: .utf8) {
                        seedEntries.append(json)
                    }
                }
            }

            // Evening pattern (7pm-9pm): Chill mode
            for hour in 19...20 {
                for minute in [0, 30] {
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
                    components.hour = hour
                    components.minute = minute
                    guard let timestamp = Calendar.current.date(from: components) else { continue }

                    let entry = ActivityLogEntry(
                        timestamp: ISO8601DateFormatter().string(from: timestamp),
                        ramUsage: Int.random(in: 40...55),
                        cpuUsage: Double.random(in: 10...20),
                        activeMode: "chill",
                        activeWindow: "Chrome - YouTube",
                        topProcesses: ["Chrome", "Spotify", "Safari"],
                        events: []
                    )
                    if let json = try? String(data: JSONEncoder().encode(entry), encoding: .utf8) {
                        seedEntries.append(json)
                    }
                }
            }
        }

        // Write all seed data to file
        let content = seedEntries.joined(separator: "\n") + "\n"
        do {
            try content.write(to: logFileURL, atomically: true, encoding: .utf8)
            logger.info("✅ Generated \(seedEntries.count) seed log entries")
        } catch {
            logger.error("❌ Failed to write seed data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Data Models

/// Single activity log entry
///
/// Represents system state at one point in time. Stored as one line of JSON.
struct ActivityLogEntry: Codable {
    /// ISO8601 timestamp (e.g., "2026-02-07T14:23:00Z")
    let timestamp: String

    /// RAM usage percentage (0-100)
    let ramUsage: Int

    /// CPU usage percentage
    let cpuUsage: Double

    /// Active mode at this time (build/chill/focus)
    let activeMode: String

    /// Title of frontmost window (e.g., "VS Code - server.js")
    let activeWindow: String

    /// Names of memory-heavy processes (top 5)
    let topProcesses: [String]

    /// Significant events that occurred (e.g., auto-suspensions)
    let events: [String]
}
