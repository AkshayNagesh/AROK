import Foundation

class SystemMonitor {
    static let shared = SystemMonitor()
    
    private var lastRAMUsage: RAMUsage = RAMUsage(used: 8.0, total: 16.0, percentage: 50)
    private var lastCPUUsage: Double = 0.0
    private var isMonitoring = false
    
    func startMonitoring() {
        isMonitoring = true
    }
    
    func getRAMUsage() async -> RAMUsage {
        // Use vm_stat for memory info
        let task = Process()
        task.launchPath = "/usr/bin/vm_stat"
        task.arguments = []
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return parseVMStat(output)
            }
        } catch {
            // Fallback to cached value
        }
        
        return lastRAMUsage
    }
    
    private func parseVMStat(_ output: String) -> RAMUsage {
        var pagesFree: Int64 = 0
        var pagesActive: Int64 = 0
        var pagesInactive: Int64 = 0
        var pagesWired: Int64 = 0
        var pageSize: Int64 = 4096
        
        for line in output.components(separatedBy: .newlines) {
            if line.contains("Pages free:") {
                pagesFree = extractPageValue(line)
            } else if line.contains("Pages active:") {
                pagesActive = extractPageValue(line)
            } else if line.contains("Pages inactive:") {
                pagesInactive = extractPageValue(line)
            } else if line.contains("Pages wired down:") {
                pagesWired = extractPageValue(line)
            } else if line.contains("page size of") {
                if let size = extractPageSize(line) {
                    pageSize = size
                }
            }
        }
        
        let totalPages = pagesFree + pagesActive + pagesInactive + pagesWired
        let usedPages = pagesActive + pagesWired
        let totalBytes = Int64(totalPages) * pageSize
        let usedBytes = Int64(usedPages) * pageSize
        
        let totalGB = Double(totalBytes) / 1_073_741_824.0
        let usedGB = Double(usedBytes) / 1_073_741_824.0
        let percentage = Int((usedGB / totalGB) * 100)
        
        let usage = RAMUsage(used: usedGB, total: totalGB, percentage: percentage)
        lastRAMUsage = usage
        return usage
    }
    
    private func extractPageValue(_ line: String) -> Int64 {
        let components = line.components(separatedBy: .whitespaces)
        for component in components {
            if let value = Int64(component.replacingOccurrences(of: ".", with: "")) {
                return value
            }
        }
        return 0
    }
    
    private func extractPageSize(_ line: String) -> Int64? {
        let components = line.components(separatedBy: .whitespaces)
        for component in components {
            if component.contains("bytes") {
                let numberPart = component.replacingOccurrences(of: "bytes", with: "")
                    .replacingOccurrences(of: ",", with: "")
                return Int64(numberPart)
            }
        }
        return nil
    }
    
    func getCPUUsage() async -> Double {
        let task = Process()
        task.launchPath = "/usr/bin/top"
        task.arguments = ["-l", "1", "-n", "0"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return parseCPUUsage(output)
            }
        } catch {
            // Fallback to cached value
        }
        
        return lastCPUUsage
    }
    
    private func parseCPUUsage(_ output: String) -> Double {
        for line in output.components(separatedBy: .newlines) {
            if line.contains("CPU usage:") {
                let components = line.components(separatedBy: "%")
                if let first = components.first {
                    let numbers = first.components(separatedBy: .whitespaces)
                    for number in numbers.reversed() {
                        if let value = Double(number) {
                            lastCPUUsage = value
                            return value
                        }
                    }
                }
            }
        }
        return lastCPUUsage
    }
    
    func getProcessList() async -> [ProcessInfo] {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-eo", "pid,pcpu,rss,comm"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        var processes: [ProcessInfo] = []
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                
                for (index, line) in lines.enumerated() {
                    if index == 0 { continue } // Skip header
                    
                    let components = line.trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
                    
                    if components.count >= 4 {
                        if let pid = pid_t(components[0]),
                           let cpu = Double(components[1]),
                           let rssKB = Double(components[2]) {
                            let name = components[3]
                            let memoryMB = rssKB / 1024.0
                            
                            // Only include processes using > 100MB
                            if memoryMB > 100 {
                                processes.append(ProcessInfo(
                                    id: pid,
                                    pid: pid,
                                    name: name,
                                    cpuUsage: cpu,
                                    memoryMB: memoryMB
                                ))
                            }
                        }
                    }
                }
            }
        } catch {
            // Return empty array on error
        }
        
        // Sort by memory usage descending
        return processes.sorted { $0.memoryMB > $1.memoryMB }
    }
    
    func getActiveWindowTitle() async -> String? {
        // Use AppleScript to get active window
        let script = """
        tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
            tell process frontApp
                set windowTitle to name of window 1
            end tell
        end tell
        return windowTitle
        """
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            // Return nil on error
        }
        
        return nil
    }
}
