import SwiftUI
import Combine
import UserNotifications

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var currentMode: IntentMode = .focus
    @Published var ramUsage: RAMUsage = RAMUsage(used: 8.0, total: 16.0, percentage: 50)
    @Published var cpuUsage: Double = 0.0
    @Published var processes: [ProcessInfo] = []
    @Published var isDemoMode: Bool = false
    @Published var suspendedProcesses: Set<pid_t> = []
    
    private var cancellables = Set<AnyCancellable>()
    
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
    }
    
    @MainActor
    func updateMetrics() async {
        ramUsage = await SystemMonitor.shared.getRAMUsage()
        cpuUsage = await SystemMonitor.shared.getCPUUsage()
        processes = await SystemMonitor.shared.getProcessList()
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
    
    func suspendProcess(_ pid: pid_t) async {
        let result = await ProcessIntervener.shared.suspend(pid: pid)
        if result == .success {
            await MainActor.run {
                suspendedProcesses.insert(pid)
            }
        }
    }
    
    func resumeProcess(_ pid: pid_t) async {
        let result = await ProcessIntervener.shared.resume(pid: pid)
        if result == .success {
            await MainActor.run {
                suspendedProcesses.remove(pid)
            }
        }
    }
    
    func autoSuspendIfNeeded() async {
        guard !isDemoMode else { return }
        
        let ramUsage = await SystemMonitor.shared.getRAMUsage()
        if ramUsage.percentage > 85 {
            let processes = await SystemMonitor.shared.getProcessList()
            
            // Use AI advisor for enhanced scoring (0-latency heuristic-based)
            let scores = await AIAdvisor.shared.getProcessScores(processes: processes, mode: currentMode)
            
            // Suspend lowest priority processes (high score = low priority = suspend)
            let toSuspend = processes
                .compactMap { proc -> (pid_t, Double)? in
                    guard let score = scores[proc.pid], score > 0.7 else { return nil }
                    return (proc.pid, score)
                }
                .sorted { $0.1 > $1.1 }
                .prefix(3)
                .map { $0.0 }
            
            for pid in toSuspend {
                await suspendProcess(pid)
            }
            
            // Show notification if we suspended processes
            if !toSuspend.isEmpty {
                await MainActor.run {
                    showNotification(title: "Memory Pressure Detected", body: "Suspended \(toSuspend.count) low-priority processes")
                }
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
