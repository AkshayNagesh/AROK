import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main content
            ScrollView {
                VStack(spacing: 20) {
                    // RAM Gauge
                    ramGaugeView

                    // Metrics Dashboard
                    metricsView

                    // Browser Tabs Section
                    browserTabsView

                    // File Cleanup Section
                    cleanupView

                    // AI Predictions Section
                    predictionsView

                    // Mode Selector
                    modeSelectorView

                    // Process List
                    processListView
                }
                .padding()
            }
            
            // Footer
            footerView
        }
        .frame(width: 360, height: 500)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                // Additional glassmorphism layer
                Color.white.opacity(0.05)
            }
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private var headerView: some View {
        HStack {
            Text("AROK")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Demo Mode Toggle
            Button(action: {
                appState.toggleDemoMode()
            }) {
                Image(systemName: appState.isDemoMode ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(appState.isDemoMode ? .green : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Demo Mode (CMD+Shift+D)")

            // AI Analyze Button
            Button(action: {
                appState.analyzePatternsWithAI()
            }) {
                HStack(spacing: 4) {
                    if appState.isAnalyzingPatterns {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "brain")
                    }
                    Text("Analyze")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(appState.isAnalyzingPatterns)
            .help("Analyze patterns with AI")

            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.black.opacity(0.1))
    }
    
    private var ramGaugeView: some View {
        VStack(spacing: 12) {
            Text("Memory Usage")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(appState.ramUsage.percentage) / 100.0)
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: appState.ramUsage.percentage)
                
                // Percentage text
                VStack(spacing: 4) {
                    Text("\(appState.ramUsage.percentage)%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(gaugeColor)
                    
                    Text("\(String(format: "%.1f", appState.ramUsage.used))/\(String(format: "%.1f", appState.ramUsage.total)) GB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // CPU Usage
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.secondary)
                Text("CPU: \(Int(appState.cpuUsage))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Auto-suspend indicator
                if appState.ramUsage.percentage > 85 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("High Pressure")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .background(
                    VisualEffectView(material: .popover, blendingMode: .behindWindow)
                        .cornerRadius(12)
                )
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var gaugeColor: Color {
        if appState.ramUsage.percentage <= 70 {
            return .green
        } else if appState.ramUsage.percentage <= 85 {
            return .yellow
        } else {
            return .red
        }
    }

    /// Metrics dashboard showing user impact
    ///
    /// Displays freeze prevention stats, RAM saved, time saved, and processes managed.
    /// All metrics are persisted and updated in real-time.
    private var metricsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Your Impact")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    MetricCard(
                        icon: "shield.fill",
                        value: "\(appState.metrics.freezesPrevented)",
                        label: "Freezes Prevented"
                    )

                    MetricCard(
                        icon: "memorychip.fill",
                        value: appState.metrics.ramSavedFormatted,
                        label: "RAM Saved"
                    )
                }

                HStack(spacing: 12) {
                    MetricCard(
                        icon: "clock.fill",
                        value: appState.metrics.timeSavedFormatted,
                        label: "Time Saved"
                    )

                    MetricCard(
                        icon: "gearshape.2.fill",
                        value: "\(appState.metrics.processesSuspended)",
                        label: "Processes Managed"
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .background(
                    VisualEffectView(material: .popover, blendingMode: .behindWindow)
                        .cornerRadius(12)
                )
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    /// Browser tabs section showing tab counts by category
    ///
    /// Displays categorized browser tabs (media, dev, social, docs) with estimated RAM usage.
    /// Provides "Suspend Media" button when media tabs are detected.
    private var browserTabsView: some View {
        Group {
            if let tabs = appState.browserTabs {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "safari.fill")
                            .foregroundColor(.blue)
                        Text("Browser Tabs")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: {
                            appState.loadBrowserTabs()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    VStack(spacing: 8) {
                        TabCategoryRow(
                            icon: "play.tv.fill",
                            label: "Media",
                            count: tabs.media.count,
                            color: .red
                        )

                        TabCategoryRow(
                            icon: "chevron.left.forwardslash.chevron.right",
                            label: "Development",
                            count: tabs.dev.count,
                            color: .green
                        )

                        TabCategoryRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            label: "Social",
                            count: tabs.social.count,
                            color: .blue
                        )

                        TabCategoryRow(
                            icon: "doc.text.fill",
                            label: "Documents",
                            count: tabs.docs.count,
                            color: .orange
                        )
                    }

                    HStack(spacing: 8) {
                        Text("Est. RAM: \(String(format: "%.1f", tabs.estimatedRAM()))GB")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if tabs.media.count > 0 {
                            Button(action: {
                                appState.suspendMediaTabs()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "pause.circle.fill")
                                    Text("Suspend Media")
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .background(
                            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                                .cornerRadius(12)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
            } else if appState.isLoadingTabs {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading browser tabs...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }

    /// File cleanup section with AI-powered analysis
    ///
    /// Allows users to request cleanup in natural language (e.g., "delete files older than 2 years").
    /// Shows analysis results with file counts, warnings, and execute button.
    private var cleanupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                Text("File Cleanup")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Text input for cleanup request
            TextField("e.g., delete files older than 2 years", text: $appState.cleanupRequest)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .foregroundColor(.primary)

            // Analyze button
            Button(action: {
                appState.analyzeCleanupRequest()
            }) {
                HStack(spacing: 6) {
                    if appState.isAnalyzingCleanup {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(appState.isAnalyzingCleanup ? "Analyzing..." : "Analyze with AI")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(appState.cleanupRequest.isEmpty ? Color.gray.opacity(0.3) : Color.blue.opacity(0.8))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(appState.cleanupRequest.isEmpty || appState.isAnalyzingCleanup)

            // Show cleanup plan if available
            if let plan = appState.cleanupPlan {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.summary)
                        .font(.caption)
                        .foregroundColor(.primary)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Files to delete: \(plan.filesToDelete.count)")
                                .font(.caption2)
                                .foregroundColor(.red)
                            if !plan.warnings.isEmpty {
                                Text("Warnings: \(plan.warnings.count)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }

                        Spacer()

                        Button(action: {
                            appState.executeCleanupPlan()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.circle.fill")
                                Text("Delete Files")
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Show warning details if any
                    if !plan.warnings.isEmpty {
                        Divider()
                            .background(Color.orange.opacity(0.3))
                            .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption2)
                                Text("Files Skipped (may be important):")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }

                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(plan.warnings.prefix(5).enumerated()), id: \.offset) { _, warning in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text((warning.file as NSString).lastPathComponent)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.orange)
                                                .lineLimit(1)
                                                .truncationMode(.middle)

                                            Text(warning.reason)
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                        .padding(.vertical, 2)

                                        if warning.file != plan.warnings.prefix(5).last?.file {
                                            Divider()
                                                .background(Color.gray.opacity(0.2))
                                        }
                                    }

                                    if plan.warnings.count > 5 {
                                        Text("+ \(plan.warnings.count - 5) more warnings")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                            }
                            .frame(maxHeight: 100)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
                .padding(10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // Show result if available
            if let result = appState.cleanupResult {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Cleanup Complete!")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }

                    Text("Deleted: \(result.deletedCount) files")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Freed: \(String(format: "%.1f", result.freedGB))GB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if result.failedCount > 0 {
                        Text("Failed: \(result.failedCount) files")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .background(
                    VisualEffectView(material: .popover, blendingMode: .behindWindow)
                        .cornerRadius(12)
                )
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    /// AI Predictions section showing active predictions and insights
    ///
    /// Displays currently active prediction with trigger, recommendation, and confidence.
    /// Shows AI insights when predictions exist but aren't currently active.
    private var predictionsView: some View {
        Group {
            if let activePrediction = appState.activePrediction {
                // Active prediction - show prominently
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        Text("AI Prediction Active")
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(activePrediction.trigger)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Text(activePrediction.recommendation)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 4)

                        HStack {
                            Text("Confidence:")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                            Text("\(Int(activePrediction.confidence * 100))%")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                        .padding(.top, 2)
                    }
                    .padding(10)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(8)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .background(
                            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                                .cornerRadius(12)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
            } else if let predictions = appState.predictions, !predictions.insights.isEmpty {
                // Predictions exist but not currently active - show insights
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("AI Insights")
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    Text(predictions.insights)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)

                    Text("\(predictions.patterns.count) patterns identified")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .background(
                            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                                .cornerRadius(12)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
            }
        }
    }

    private var modeSelectorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mode")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(IntentMode.allCases, id: \.self) { mode in
                    Button(action: {
                        appState.setMode(mode)
                    }) {
                        Text(mode.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(appState.currentMode == mode ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(appState.currentMode == mode ? 
                                          Color.blue.opacity(0.8) : 
                                          Color.white.opacity(0.15))
                            )
                            .shadow(color: appState.currentMode == mode ? 
                                   Color.blue.opacity(0.3) : 
                                   Color.clear, radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .background(
                    VisualEffectView(material: .popover, blendingMode: .behindWindow)
                        .cornerRadius(12)
                )
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var processListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Processes")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if appState.processes.isEmpty {
                Text("No processes found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(appState.processes.prefix(5)) { process in
                    ProcessRow(process: process, appState: appState)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .background(
                    VisualEffectView(material: .popover, blendingMode: .behindWindow)
                        .cornerRadius(12)
                )
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var footerView: some View {
        HStack {
            if appState.isDemoMode {
                Text("DEMO MODE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.2))
                    )
            }
            
            Spacer()
            
            Text("AROK v2.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.black.opacity(0.1))
    }
}

struct ProcessRow: View {
    let process: ProcessInfo
    @ObservedObject var appState: AppState
    
    var isSuspended: Bool {
        appState.suspendedProcesses.contains(process.pid)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(process.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSuspended ? .secondary : .primary)
                
                Text("\(String(format: "%.1f", process.memoryGB)) GB • \(String(format: "%.1f", process.cpuUsage))% CPU")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    if isSuspended {
                        await appState.resumeProcess(process.pid)
                    } else {
                        await appState.suspendProcess(process.pid)
                    }
                }
            }) {
                Image(systemName: isSuspended ? "play.circle.fill" : "pause.circle.fill")
                    .foregroundColor(isSuspended ? .green : .orange)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

/// Tab category row showing icon, label, and count badge
///
/// Used in browser tabs section to display each category with color coding.
struct TabCategoryRow: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
                .font(.subheadline)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(0.3))
                .cornerRadius(6)
        }
        .padding(.vertical, 2)
    }
}

/// Individual metric card displaying an icon, value, and label
///
/// Used in the metrics dashboard to show key statistics in a compact,
/// visually consistent format.
struct MetricCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.system(size: 14))

                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
