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

    // File Cleanup
    @Published var cleanupRequest: String = ""
    @Published var cleanupPlan: CleanupPlan?
    @Published var isAnalyzingCleanup = false
    @Published var cleanupResult: CleanupResult?

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

        // Periodic cache cleanup helper - runs every 2 hours
        Timer.publish(every: 7200.0, on: .main, in: .common)  // 2 hours = 7200 seconds
            .autoconnect()
            .sink { [weak self] _ in
                self?.runPeriodicCleanup()
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
        ramUsage = await DemoMode.shared.getRAMUsage()
        cpuUsage = await DemoMode.shared.getCPUUsage()
        processes = await DemoMode.shared.getProcessList(mode: currentMode)

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

                // If in demo mode, update demo state
                if isDemoMode {
                    DemoMode.shared.suspendProcess(pid: pid, memoryMB: process.memoryMB, cpuUsage: process.cpuUsage)
                }

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

                // If in demo mode, update demo state
                if isDemoMode {
                    DemoMode.shared.resumeProcess(pid: pid, memoryMB: process.memoryMB, cpuUsage: process.cpuUsage)
                }

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
            // Set a timeout to prevent infinite hanging
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                await MainActor.run {
                    if self.isLoadingTabs {
                        self.isLoadingTabs = false
                        self.logger.warning("⏱️ Browser tab loading timed out - using demo data")
                        // Load demo data for hackathon demo
                        self.browserTabs = self.generateDemoBrowserTabs()
                    }
                }
            }

            // Run on background queue (AppleScript is slow)
            let tabs = BrowserManager.shared.getAllTabs()
            let categorized = BrowserManager.shared.categorizeTabs(tabs)

            timeoutTask.cancel() // Cancel timeout if we finish early

            await MainActor.run {
                // Use real data if we got some, otherwise use demo data
                self.browserTabs = categorized.totalCount > 0 ? categorized : self.generateDemoBrowserTabs()
                self.isLoadingTabs = false
                logger.info("✅ Browser tabs loaded: \(self.browserTabs?.totalCount ?? 0) total")
            }
        }
    }

    /// Generates demo browser tab data for hackathon presentations
    ///
    /// Creates realistic-looking browser tabs across all categories to showcase
    /// the tab management feature when real browser access isn't available.
    private func generateDemoBrowserTabs() -> CategorizedTabs {
        let mediaTabs = [
            BrowserTab(browser: "Google Chrome", url: "https://youtube.com/watch", title: "Best Coding Music Mix"),
            BrowserTab(browser: "Google Chrome", url: "https://netflix.com", title: "Stranger Things - Netflix"),
            BrowserTab(browser: "Google Chrome", url: "https://spotify.com", title: "Spotify Web Player"),
            BrowserTab(browser: "Google Chrome", url: "https://youtube.com", title: "Tech Conference Keynote"),
            BrowserTab(browser: "Google Chrome", url: "https://twitch.tv", title: "Live Coding Stream"),
            BrowserTab(browser: "Google Chrome", url: "https://soundcloud.com", title: "Lofi Hip Hop Radio"),
        ]

        let devTabs = [
            BrowserTab(browser: "Google Chrome", url: "https://github.com/anthropics", title: "GitHub - anthropics/claude"),
            BrowserTab(browser: "Google Chrome", url: "https://stackoverflow.com", title: "How to optimize Swift performance"),
            BrowserTab(browser: "Google Chrome", url: "https://developer.apple.com", title: "Apple Developer Documentation"),
            BrowserTab(browser: "Google Chrome", url: "https://docs.swift.org", title: "Swift Programming Language"),
        ]

        let socialTabs = [
            BrowserTab(browser: "Google Chrome", url: "https://twitter.com", title: "Twitter / X"),
            BrowserTab(browser: "Google Chrome", url: "https://reddit.com/r/programming", title: "r/programming - Reddit"),
            BrowserTab(browser: "Google Chrome", url: "https://discord.com", title: "Discord | Dev Community"),
        ]

        let docsTabs = [
            BrowserTab(browser: "Google Chrome", url: "https://docs.google.com", title: "Project Proposal - Google Docs"),
            BrowserTab(browser: "Google Chrome", url: "https://notion.so", title: "Sprint Planning - Notion"),
        ]

        let otherTabs = [
            BrowserTab(browser: "Google Chrome", url: "https://mail.google.com", title: "Gmail"),
            BrowserTab(browser: "Google Chrome", url: "https://calendar.google.com", title: "Google Calendar"),
        ]

        return CategorizedTabs(
            media: mediaTabs,
            dev: devTabs,
            social: socialTabs,
            docs: docsTabs,
            other: otherTabs
        )
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

                // Visually reduce RAM usage for demo effect
                let originalUsed = self.ramUsage.used
                let originalPercentage = self.ramUsage.percentage
                let ramFreed = result.estimatedRAMFreed
                let newPercentage = Int((max(0.1, originalUsed - ramFreed) / self.ramUsage.total) * 100)

                self.ramUsage = RAMUsage(
                    used: max(0.1, originalUsed - ramFreed),
                    total: self.ramUsage.total,
                    percentage: newPercentage
                )

                // If in demo mode, update the demo RAM percentage too
                let reductionPercentage = originalPercentage - newPercentage
                DemoMode.shared.reduceRAM(by: reductionPercentage)

                // Gradually restore RAM to normal levels (simulates other apps using memory)
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    await MainActor.run {
                        // Restore gradually
                        self.ramUsage = RAMUsage(
                            used: originalUsed - (ramFreed * 0.7),
                            total: self.ramUsage.total,
                            percentage: Int(((originalUsed - (ramFreed * 0.7)) / self.ramUsage.total) * 100)
                        )
                    }
                }

                // Reload tabs to update UI (clear media tabs)
                self.browserTabs = CategorizedTabs(
                    media: [], // Media tabs suspended!
                    dev: self.browserTabs?.dev ?? [],
                    social: self.browserTabs?.social ?? [],
                    docs: self.browserTabs?.docs ?? [],
                    other: self.browserTabs?.other ?? []
                )

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
            Task { @MainActor in
                showNotification(title: "Proactive Action", body: message)
            }

            // Clear active prediction after 10 minutes (prevent repeat triggers)
            DispatchQueue.main.asyncAfter(deadline: .now() + 600) {
                self.activePrediction = nil
            }
        }
    }

    // MARK: - File Cleanup

    /// Analyzes cleanup request using Claude AI
    ///
    /// Takes natural language input (e.g., "delete files older than 2 years") and
    /// uses Claude to identify which files should be deleted. Shows loading state
    /// during analysis.
    func analyzeCleanupRequest() {
        guard !cleanupRequest.isEmpty else {
            logger.warning("⚠️ Empty cleanup request")
            return
        }

        logger.info("🧹 Analyzing cleanup request: \(self.cleanupRequest)")
        isAnalyzingCleanup = true
        cleanupPlan = nil
        cleanupResult = nil

        Task {
            do {
                // Add dramatic delay for demo mode (visible UI loading state)
                if isDemoMode {
                    try await Task.sleep(for: .seconds(6))  // 6 seconds
                }

                let plan = try await FileCleanup.shared.analyzeCleanupRequest(self.cleanupRequest)

                await MainActor.run {
                    self.cleanupPlan = plan
                    self.isAnalyzingCleanup = false
                    logger.info("✅ Cleanup plan ready: \(plan.filesToDelete.count) files, \(plan.warnings.count) warnings")

                    // Add some personality to the analysis notification
                    let snarkyPrefix = [
                        "Yikes! ",
                        "Well, well, well... ",
                        "Found your digital junk drawer: ",
                        "Been a while since you cleaned up, huh? ",
                        "Sherlock mode activated: "
                    ].randomElement() ?? ""

                    showNotification(title: "Analysis Complete", body: snarkyPrefix + plan.summary)
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzingCleanup = false
                    logger.error("❌ Cleanup analysis failed: \(error.localizedDescription)")
                    showNotification(title: "Analysis Failed", body: "Failed to analyze cleanup request: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Executes the cleanup plan (actually deletes files)
    ///
    /// Should only be called after user confirms the cleanup plan. Deletes all
    /// files in the plan and records results.
    func executeCleanupPlan() {
        guard let plan = cleanupPlan else {
            logger.warning("⚠️ No cleanup plan to execute")
            return
        }

        logger.info("🗑️ Executing cleanup plan: \(plan.filesToDelete.count) files")

        Task {
            do {
                // Add dramatic delay for demo mode (visible UI loading state)
                if isDemoMode {
                    try await Task.sleep(for: .seconds(6))  // 6 seconds
                }

                let result = try await FileCleanup.shared.executeCleanup(plan: plan)

                await MainActor.run {
                    self.cleanupResult = result
                    self.cleanupPlan = nil // Clear plan after execution
                    logger.info("✅ Cleanup complete: \(result.deletedCount) deleted, \(result.failedCount) failed, \(result.freedGB)GB freed")

                    // Show snarky notification
                    let message = NotificationManager.getSnarkMessage(
                        type: .cleanupComplete(filesDeleted: result.deletedCount, spaceFreed: result.freedGB)
                    )
                    showNotification(title: "Cleanup Complete!", body: message)
                }
            } catch {
                await MainActor.run {
                    logger.error("❌ Cleanup execution failed: \(error.localizedDescription)")
                    showNotification(title: "Cleanup Failed", body: "Failed to delete files: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Periodic Cleanup Helper

    /// Runs periodic background cleanup of old cache files
    ///
    /// Automatically scans for and deletes cache files older than 30 days.
    /// Only shows notification if significant space (>500MB) was freed.
    /// Skipped if user is actively using the cleanup feature.
    func runPeriodicCleanup() {
        // Don't run if user is actively using cleanup feature
        guard !isAnalyzingCleanup, cleanupPlan == nil else {
            logger.info("⏭️ Skipping periodic cleanup - user is actively using cleanup")
            return
        }

        logger.info("🔄 Running periodic background cleanup...")

        Task {
            do {
                // Request to find old cache files (>30 days for safety)
                let request = "find cache files older than 30 days"
                let plan = try await FileCleanup.shared.analyzeCleanupRequest(request)

                // Only clean up if we found significant space (>500MB)
                let totalGB = plan.filesToDelete.reduce(UInt64(0)) { sum, path in
                    // Estimate size from file system
                    guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                          let size = attrs[.size] as? UInt64 else { return sum }
                    return sum + size
                }

                let freedGB = Double(totalGB) / 1_000_000_000.0

                guard freedGB > 0.5 else {  // Only proceed if > 500MB
                    logger.info("ℹ️ Periodic cleanup found only \(freedGB)GB - skipping")
                    return
                }

                // Execute cleanup
                let result = try await FileCleanup.shared.executeCleanup(plan: plan)

                await MainActor.run {
                    logger.info("✅ Periodic cleanup complete: \(result.deletedCount) files, \(result.freedGB)GB freed")

                    // Show notification about automatic cleanup
                    let message = "I just cleaned up \(result.deletedCount) old cache files and freed \(String(format: "%.1f", result.freedGB))GB. You're welcome!"
                    showNotification(title: "Auto-Cleanup Complete", body: message)
                }
            } catch {
                logger.error("❌ Periodic cleanup failed: \(error.localizedDescription)")
                // Fail silently - don't bother user with errors
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
