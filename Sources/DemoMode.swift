import Foundation

class DemoMode {
    static let shared = DemoMode()
    
    private var isActive = false
    
    func activate() {
        isActive = true
    }
    
    func deactivate() {
        isActive = false
    }
    
    func getRAMUsage() async -> RAMUsage {
        if isActive {
            // Simulate RAM spike
            return RAMUsage(used: 14.0, total: 16.0, percentage: 88)
        }
        return await SystemMonitor.shared.getRAMUsage()
    }
    
    func getCPUUsage() async -> Double {
        if isActive {
            return 75.0
        }
        return await SystemMonitor.shared.getCPUUsage()
    }
    
    func getProcessList() async -> [ProcessInfo] {
        if isActive {
            // Return demo processes
            return [
                ProcessInfo(id: 99999, pid: 99999, name: "demo-worker", cpuUsage: 10.0, memoryMB: 1024),
                ProcessInfo(id: 99998, pid: 99998, name: "Chrome", cpuUsage: 5.0, memoryMB: 512),
                ProcessInfo(id: 99997, pid: 99997, name: "Spotify", cpuUsage: 2.0, memoryMB: 256),
                ProcessInfo(id: 99996, pid: 99996, name: "Docker", cpuUsage: 15.0, memoryMB: 2048)
            ]
        }
        return await SystemMonitor.shared.getProcessList()
    }
}
