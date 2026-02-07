import SwiftUI
import Combine
import UserNotifications
import os.log

/// Central state management for AROK application
///
/// AppState is the single source of truth for all application state, coordinating
/// between system monitoring, process management, metrics tracking, and UI updates.
/// Uses Combine's @Published properties to automatically update SwiftUI views.
///
/// Threading: All @Published properties must be updated on MainActor
/// Singleton: Shared instance accessed via AppState.shared
class AppState: ObservableObject {
    static let shared = AppState()
    private let logger = Logger(subsystem: "com.arok.app", category: "AppState")

    // MARK: - Published State

    @Published var currentMode: IntentMode = .focus
    @Published var ramUsage: RAMUsage = RAMUsage(used: 8.0, total: 16.0, percentage: 50)
    @Published var cpuUsage: Double = 0.0
    @Published var processes: [ProcessInfo] = []
    @Published var isDemoMode: Bool = false
    @Published var suspendedProcesses: Set<pid_t> = []
    @Published var browserTabs: CategorizedTabs?
    @Published var isLoadingTabs = false
    @Published var predictions: PredictionResult?
    @Published var isAnalyzingPatterns = false
    @Published var activePrediction: Pattern?

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    /// Counter for tracking update cycles (used for periodic snapshot recording)
    private var updateCounter = 0

    // MARK: - Computed Properties

    /// Exposes current metrics from MetricsManager
    ///
    /// Provides read-only access to metrics for UI binding. Metrics are managed
    /// by MetricsManager and automatically persisted.
    var metrics: MetricsData {
        return MetricsManager.shared.metrics
    }
    
    init() {
        // Update RAM usage every 2 seconds
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.updateMetrics()
                }
            }
            .store(in: &cancellables)

        // Load browser tabs after a short delay (let app settle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.loadBrowserTabs()
        }

        // Load saved predictions
        self.predictions = PredictiveEngine.shared.loadPredictions()
        if predictions != nil {
            logger.info("✅ Loaded saved predictions on startup")
        }

        // Check predictive actions every 60 seconds
        Timer.publish(every: 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPredictiveActions()
            }
            .store(in: &cancellables)
    }
    
    /// Updates all system metrics (RAM, CPU, processes)
    ///
    /// Called every 2 seconds by timer. Also records periodic snapshots for historical
    /// tracking (every 10 minutes = 300 updates at 2-second intervals).
    ///
    /// Threading: Must be called on MainActor since it updates @Published properties
    @MainActor
    func updateMetrics() async {
        ramUsage = await SystemMonitor.shared.getRAMUsage()
        cpuUsage = await SystemMonitor.shared.getCPUUsage()
        processes = await SystemMonitor.shared.getProcessList()

        // Record periodic snapshot for historical tracking
        // Every 300 updates at 2-second intervals = 10 minutes
        updateCounter += 1
        if updateCounter % 300 == 0 {
            MetricsManager.shared.recordSnapshot(
                ramUsage: ramUsage.percentage,
                cpuUsage: cpuUsage,
                mode: currentMode.rawValue
            )
            logger.debug("📸 Recorded metrics snapshot")
        }
    }
    
    func setMode(_ mode: IntentMode) {
        currentMode = mode
        Task {
            await autoSuspendIfNeeded()
        }
    }
    
    func toggleDemoMode() {
        isDemoMode.toggle()
        if isDemoMode {
            DemoMode.shared.activate()
        } else {
            DemoMode.shared.deactivate()
        }
    }
    
    /// Manually suspends a process and records metrics
    ///
    /// - Parameter pid: Process ID to suspend
    ///
    /// Records the manual suspension in metrics and shows a snarky notification.
    /// Updates suspendedProcesses set on success.
    func suspendProcess(_ pid: pid_t) async {
        // Find the process to get its details
        guard let process = processes.first(where: { $0.pid == pid }) else {
            logger.warning("⚠️ Attempted to suspend unknown PID: \(pid)")
            return
        }

        let result = await ProcessIntervener.shared.suspend(pid: pid)
        if result == .success {
            await MainActor.run {
                suspendedProcesses.insert(pid)

                // Record manual suspension metrics
                MetricsManager.shared.recordManualSuspension(
                    processName: process.name,
                    ramFreedMB: process.memoryMB
                )

                // Show snarky notification
                let message = NotificationManager.getSnarkMessage(
                    type: .manualSuspend(processName: process.name)
                )
                showNotification(title: "Process Suspended", body: message)

                logger.info("✅ Manual suspension: \(process.name) (PID: \(pid))")
            }
        } else {
            logger.error("❌ Failed to suspend: \(process.name) (PID: \(pid))")
        }
    }

    /// Resumes a suspended process
    ///
    /// - Parameter pid: Process ID to resume
    ///
    /// Shows a snarky notification on successful resume.
    func resumeProcess(_ pid: pid_t) async {
        // Find the process to get its details
        guard let process = processes.first(where: { $0.pid == pid }) else {
            logger.warning("⚠️ Attempted to resume unknown PID: \(pid)")
            return
        }

        let result = await ProcessIntervener.shared.resume(pid: pid)
        if result == .success {
            await MainActor.run {
                suspendedProcesses.remove(pid)

                // Show snarky notification
                let message = NotificationManager.getSnarkMessage(
                    type: .resume(processName: process.name)
                )
                showNotification(title: "Process Resumed", body: message)

                logger.info("✅ Resumed: \(process.name) (PID: \(pid))")
            }
        } else {
            logger.error("❌ Failed to resume: \(process.name) (PID: \(pid))")
        }
    }
    
    /// Automatically suspends processes when RAM exceeds threshold (85%)
    ///
    /// Uses AI advisor for smart process scoring, then suspends top 3 lowest-priority
    /// processes (highest suspension scores). Records metrics for freeze prevention
    /// and shows snarky notification.
    ///
    /// - Note: Skipped in demo mode to prevent interfering with demo
    /// - Note: Only suspends processes with score > 0.7 (clear candidates)
    func autoSuspendIfNeeded() async {
        guard !isDemoMode else { return }

        let ramUsage = await SystemMonitor.shared.getRAMUsage()

        // Check if we're above the danger threshold
        guard ramUsage.percentage > 85 else { return }

        logger.warning("⚠️ RAM threshold exceeded: \(ramUsage.percentage)%")

        let processes = await SystemMonitor.shared.getProcessList()

        // Use AI advisor for enhanced scoring (0-latency heuristic-based)
        let scores = await AIAdvisor.shared.getProcessScores(processes: processes, mode: currentMode)

        // Find processes with high suspension scores (> 0.7 = clear candidates)
        // Sort by score descending, take top 3
        let toSuspend = processes
            .compactMap { proc -> (ProcessInfo, Double)? in
                guard let score = scores[proc.pid], score > 0.7 else { return nil }
                return (proc, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)

        guard !toSuspend.isEmpty else {
            logger.info("ℹ️ No suitable processes to suspend")
            return
        }

        // Track which processes we successfully suspended
        var totalFreed = 0.0
        var suspendedNames: [String] = []

        for (process, _) in toSuspend {
            let result = await ProcessIntervener.shared.suspend(pid: process.pid)
            if result == .success {
                await MainActor.run {
                    suspendedProcesses.insert(process.pid)
                }
                totalFreed += process.memoryMB
                suspendedNames.append(process.name)
                logger.info("🛑 Auto-suspended: \(process.name) (\(process.memoryMB)MB)")
            }
        }

        // Record metrics and notify user
        if !suspendedNames.isEmpty {
            await MainActor.run {
                // Record freeze prevention in metrics
                MetricsManager.shared.recordFreezePrevented(
                    ramFreedGB: totalFreed / 1024.0,
                    processNames: suspendedNames
                )

                // Show snarky notification
                let message = NotificationManager.getSnarkMessage(
                    type: .autoSuspend(count: suspendedNames.count, ramFreed: totalFreed / 1024.0)
                )
                showNotification(title: "Freeze Prevented!", body: message)

                logger.info("✅ Auto-suspend complete: \(suspendedNames.count) processes, \(totalFreed)MB freed")
            }
        }
    }
    
    // MARK: - Browser Tab Management

    /// Loads browser tabs from all running Chromium browsers
    ///
    /// Runs asynchronously in background to avoid blocking UI. Updates browserTabs
    /// property with categorized results.
    ///
    /// - Note: Called automatically 2 seconds after app launch and can be manually triggered
    func loadBrowserTabs() {
        logger.info("🌐 Loading browser tabs...")
        isLoadingTabs = true

        Task {
            // Run on background queue (AppleScript is slow)
            let tabs = BrowserManager.shared.getAllTabs()
            let categorized = BrowserManager.shared.categorizeTabs(tabs)

            await MainActor.run {
                self.browserTabs = categorized
                self.isLoadingTabs = false
                logger.info("✅ Browser tabs loaded: \(categorized.totalCount) total")
            }
        }
    }

    /// Suspends all media tabs to free memory
    ///
    /// Closes media category tabs (YouTube, Netflix, Spotify, etc.) from all browsers.
    /// Records metrics and shows snarky notification on success.
    func suspendMediaTabs() {
        guard let tabs = browserTabs?.media else {
            logger.warning("⚠️ No media tabs to suspend")
            return
        }

        guard !tabs.isEmpty else {
            logger.warning("⚠️ Media tabs list is empty")
            return
        }

        logger.info("🛑 Suspending \(tabs.count) media tabs...")

        Task {
            // Run suspension on background queue
            let result = BrowserManager.shared.suspendTabs(tabs)

            await MainActor.run {
                // Record metrics for freeze prevention
                MetricsManager.shared.recordFreezePrevented(
                    ramFreedGB: result.estimatedRAMFreed,
                    processNames: ["Browser tabs"]
                )

                // Show snarky notification
                let message = NotificationManager.getSnarkMessage(
                    type: .tabsSuspended(count: result.suspendedCount, ramFreed: result.estimatedRAMFreed)
                )
                showNotification(title: "Tabs Suspended", body: message)

                // Reload tabs to update UI
                loadBrowserTabs()

                logger.info("✅ Media tabs suspended: \(result.suspendedCount) tabs, \(result.estimatedRAMFreed)GB freed")
            }
        }
    }

    // MARK: - Predictive AI

    /// Analyzes activity patterns using Claude AI
    ///
    /// Sends recent activity logs to Claude for pattern analysis. Shows loading state
    /// during analysis and updates predictions property with results.
    ///
    /// Called when user clicks "Analyze" button in UI.
    func analyzePatternsWithAI() {
        logger.info("🧠 Starting AI pattern analysis...")
        isAnalyzingPatterns = true

        Task {
            do {
                let result = try await PredictiveEngine.shared.analyzePatterns()

                await MainActor.run {
                    self.predictions = result
                    self.isAnalyzingPatterns = false
                    logger.info("✅ Pattern analysis complete: \(result.patterns.count) patterns found")

                    // Show notification with insights
                    showNotification(title: "AI Analysis Complete", body: result.insights)
                }
            } catch PredictiveError.apiKeyMissing {
                await MainActor.run {
                    self.isAnalyzingPatterns = false
                    logger.error("❌ API key not configured")
                    showNotification(title: "Error", body: "Claude API key not configured. Set ANTHROPIC_API_KEY environment variable.")
                }
            } catch PredictiveError.noData {
                await MainActor.run {
                    self.isAnalyzingPatterns = false
                    logger.error("❌ No activity logs found")
                    showNotification(title: "Error", body: "No activity data yet. Please wait a few minutes for logs to accumulate.")
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzingPatterns = false
                    logger.error("❌ Pattern analysis failed: \(error.localizedDescription)")
                    showNotification(title: "Analysis Failed", body: "Pattern analysis failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Checks if any predicted pattern is currently active
    ///
    /// Called every 60 seconds by timer. If an active pattern is found, proactively
    /// suspends the recommended processes before memory pressure occurs.
    ///
    /// - Note: Only runs if predictions exist
    /// - Note: Clears active prediction after 10 minutes
    func checkPredictiveActions() {
        guard let predictions = predictions else { return }

        // Check if any pattern matches current conditions
        if let activePattern = PredictiveEngine.shared.checkForActivePatterns(predictions) {
            // Pattern is active - take proactive action
            logger.info("🎯 Executing predictive action: \(activePattern.recommendation)")

            self.activePrediction = activePattern

            // Proactively suspend recommended processes
            for processName in activePattern.processes {
                if let process = processes.first(where: { $0.name.lowercased().contains(processName.lowercased()) }) {
                    Task {
                        await suspendProcess(process.pid)
                    }
                }
            }

            // Send snarky notification
            let message = NotificationManager.getSnarkMessage(
                type: .predictive(action: activePattern.recommendation)
            )
            showNotification(title: "Proactive Action", body: message)

            // Clear active prediction after 10 minutes (prevent repeat triggers)
            DispatchQueue.main.asyncAfter(deadline: .now() + 600) {
                self.activePrediction = nil
            }
        }
    }

    @MainActor
    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

enum IntentMode: String, CaseIterable {
    case build = "Build"
    case chill = "Chill"
    case focus = "Focus"
}

struct RAMUsage {
    let used: Double // GB
    let total: Double // GB
    let percentage: Int
}

struct ProcessInfo: Identifiable {
    let id: pid_t
    let pid: pid_t
    let name: String
    let cpuUsage: Double
    let memoryMB: Double
    
    var memoryGB: Double {
        memoryMB / 1024.0
    }
}
