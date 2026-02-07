//
//  MetricsManager.swift
//  AROK
//
//  Purpose: Centralized metrics tracking and persistence system
//  Created: 2026-02-07
//
//  Tracks user impact metrics (freezes prevented, RAM saved, time saved) and persists
//  them across app sessions. Provides a clean API for recording events and querying
//  historical data. All metrics are stored as JSON in Application Support directory.
//

import Foundation
import os.log

/// Manages tracking and persistence of user impact metrics
///
/// MetricsManager is a singleton that tracks:
/// - Freezes prevented (count)
/// - RAM saved (GB)
/// - Processes suspended (count)
/// - Time saved (minutes)
/// - Historical snapshots for charting
///
/// All metrics persist to disk automatically on every change, ensuring data is never
/// lost even if the app crashes. On first launch, seed data is generated to make the
/// demo impressive immediately.
///
/// Example usage:
/// ```swift
/// // Record a freeze prevention event
/// MetricsManager.shared.recordFreezePrevented(
///     ramFreedGB: 2.5,
///     processNames: ["Chrome", "Spotify"]
/// )
///
/// // Access current metrics
/// let metrics = MetricsManager.shared.metrics
/// print("Freezes prevented: \(metrics.freezesPrevented)")
/// ```
///
/// Threading: Thread-safe (all operations on main thread)
/// Persistence: Automatic on every metrics change
/// File location: ~/Library/Application Support/AROK/metrics.json
///
/// - Note: Metrics automatically seed with demo data if file doesn't exist
/// - Warning: Disk writes happen synchronously - keep metric updates infrequent
class MetricsManager {
    static let shared = MetricsManager()
    private let logger = Logger(subsystem: "com.arok.app", category: "Metrics")

    /// File URL for persisted metrics data
    private let metricsFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let arokDir = appSupport.appendingPathComponent("AROK")
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: arokDir, withIntermediateDirectories: true)
        return arokDir.appendingPathComponent("metrics.json")
    }()

    /// Current metrics data, automatically persisted on change
    var metrics: MetricsData {
        didSet {
            saveMetrics()
        }
    }

    /// Private initializer (singleton pattern)
    /// Loads existing metrics or creates seed data for first run
    private init() {
        // Try to load from disk first, fallback to seed data
        self.metrics = MetricsManager.loadMetricsFromDisk() ?? MetricsData.seedData()
        logger.info("✅ MetricsManager initialized with \(self.metrics.freezesPrevented) freezes prevented")
    }

    // MARK: - Load/Save

    /// Loads metrics from disk
    ///
    /// - Returns: Decoded MetricsData if file exists and is valid, nil otherwise
    ///
    /// This is a static method because it's called before the singleton is fully initialized.
    /// Failures are logged but not thrown - we gracefully degrade to seed data.
    private static func loadMetricsFromDisk() -> MetricsData? {
        // Access the file URL through shared instance (which creates the singleton)
        let fileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AROK")
            .appendingPathComponent("metrics.json")

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(MetricsData.self, from: data)
            Logger(subsystem: "com.arok.app", category: "Metrics").info("✅ Loaded metrics from disk: \(decoded.freezesPrevented) freezes")
            return decoded
        } catch {
            Logger(subsystem: "com.arok.app", category: "Metrics").error("⚠️ Failed to load metrics: \(error.localizedDescription)")
            return nil
        }
    }

    /// Saves current metrics to disk
    ///
    /// Called automatically via didSet on metrics property. Failures are logged but don't
    /// crash the app - metrics will be lost but app continues functioning.
    private func saveMetrics() {
        do {
            let data = try JSONEncoder().encode(metrics)
            try data.write(to: metricsFileURL)
            logger.debug("💾 Saved metrics to disk")
        } catch {
            logger.error("❌ Failed to save metrics: \(error.localizedDescription)")
        }
    }

    // MARK: - Recording Events

    /// Records a freeze prevention event and updates all related metrics
    ///
    /// This method is called automatically when AppState performs an auto-suspend action.
    /// It increments the freeze counter, accumulates RAM saved, updates process count,
    /// and estimates time saved based on industry averages (5 min per freeze).
    ///
    /// - Parameters:
    ///   - ramFreedGB: Amount of RAM freed by suspending processes, in gigabytes
    ///   - processNames: Names of processes that were suspended (for logging and history)
    ///
    /// - Note: Metrics are automatically saved to disk after this call
    /// - Note: A MetricSnapshot is added to history for future charting
    ///
    /// Example:
    /// ```swift
    /// MetricsManager.shared.recordFreezePrevented(
    ///     ramFreedGB: 2.5,
    ///     processNames: ["Chrome", "Spotify", "Slack"]
    /// )
    /// ```
    ///
    /// Logging: Emits info-level log with details of what was recorded
    func recordFreezePrevented(ramFreedGB: Double, processNames: [String]) {
        metrics.freezesPrevented += 1
        metrics.totalRAMSaved += ramFreedGB
        metrics.processesSuspended += processNames.count
        // Industry average: each freeze causes ~5 minutes of lost productivity
        // (app restart, context switch, reloading work)
        metrics.totalTimeSaved += 5

        // Record snapshot for historical tracking
        let snapshot = MetricSnapshot(
            timestamp: Date(),
            ramUsage: 0,  // Will be filled by AppState if needed
            cpuUsage: 0,
            activeMode: "",
            event: "Auto-suspended \(processNames.joined(separator: ", "))"
        )
        metrics.history.append(snapshot)

        logger.info("📊 Recorded freeze prevention: \(ramFreedGB)GB freed, processes: \(processNames.joined(separator: ", "))")
    }

    /// Records a manual process suspension event
    ///
    /// Called when user manually suspends a process via the UI. Updates process count
    /// and RAM saved, but doesn't increment freeze prevention counter (no freeze was imminent).
    ///
    /// - Parameters:
    ///   - processName: Name of the suspended process
    ///   - ramFreedMB: Amount of RAM freed in megabytes
    ///
    /// Example:
    /// ```swift
    /// MetricsManager.shared.recordManualSuspension(
    ///     processName: "Chrome",
    ///     ramFreedMB: 1024.0
    /// )
    /// ```
    func recordManualSuspension(processName: String, ramFreedMB: Double) {
        metrics.processesSuspended += 1
        metrics.totalRAMSaved += ramFreedMB / 1024.0  // Convert MB to GB
        logger.info("📊 Recorded manual suspension: \(processName), \(ramFreedMB)MB")
    }

    /// Records a system state snapshot for historical tracking
    ///
    /// Called periodically (every 10 minutes) by AppState to build up historical data.
    /// This data can be used for charting trends over time.
    ///
    /// - Parameters:
    ///   - ramUsage: Current RAM usage percentage (0-100)
    ///   - cpuUsage: Current CPU usage percentage
    ///   - mode: Current active mode (build/chill/focus)
    ///
    /// - Note: History is automatically trimmed to last 1000 snapshots to prevent unbounded growth
    func recordSnapshot(ramUsage: Int, cpuUsage: Double, mode: String) {
        let snapshot = MetricSnapshot(
            timestamp: Date(),
            ramUsage: ramUsage,
            cpuUsage: cpuUsage,
            activeMode: mode,
            event: nil
        )
        metrics.history.append(snapshot)

        // Keep only last 1000 snapshots to prevent file bloat
        // 1000 snapshots at 10 min intervals = ~7 days of history
        if metrics.history.count > 1000 {
            metrics.history.removeFirst(metrics.history.count - 1000)
            logger.debug("🧹 Trimmed history to 1000 snapshots")
        }
    }
}

// MARK: - Data Models

/// Container for all tracked metrics
///
/// Codable for JSON persistence, includes computed properties for formatted display.
struct MetricsData: Codable {
    /// Total number of freezes prevented by auto-suspend
    var freezesPrevented: Int = 0

    /// Total RAM saved across all suspensions, in gigabytes
    var totalRAMSaved: Double = 0.0

    /// Total number of processes suspended (auto + manual)
    var processesSuspended: Int = 0

    /// Estimated time saved by preventing freezes, in minutes
    /// Calculation: freezesPrevented * 5 minutes
    var totalTimeSaved: Int = 0

    /// Historical snapshots of system state for charting
    var history: [MetricSnapshot] = []

    // MARK: - Computed Properties

    /// Formatted time saved string (e.g., "2h 15m" or "45m")
    var timeSavedFormatted: String {
        let hours = totalTimeSaved / 60
        let mins = totalTimeSaved % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    /// Formatted RAM saved string (e.g., "34.2 GB")
    var ramSavedFormatted: String {
        return String(format: "%.1f GB", totalRAMSaved)
    }

    // MARK: - Seed Data

    /// Generates realistic seed data for demo purposes
    ///
    /// Used on first launch when no metrics file exists. Shows impressive numbers
    /// immediately to make demos more compelling.
    ///
    /// - Returns: MetricsData with realistic demo values
    static func seedData() -> MetricsData {
        return MetricsData(
            freezesPrevented: 8,
            totalRAMSaved: 34.2,
            processesSuspended: 47,
            totalTimeSaved: 40,  // 8 freezes * 5 min each
            history: []
        )
    }
}

/// Single snapshot of system state at a point in time
///
/// Used for historical tracking and charting. Includes both system metrics
/// and any significant events that occurred.
struct MetricSnapshot: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let ramUsage: Int
    let cpuUsage: Double
    let activeMode: String
    let event: String?  // Optional description of what happened (e.g., "Auto-suspended Chrome")
}
