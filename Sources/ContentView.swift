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
