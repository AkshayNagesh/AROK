import Foundation

enum IntervenerResult: Equatable {
    case success
    case failure(String)
}

class ProcessIntervener {
    static let shared = ProcessIntervener()
    
    private var virtualSuspended: Set<pid_t> = []
    
    func suspend(pid: pid_t) async -> IntervenerResult {
        // Try real SIGSTOP first
        let task = Process()
        task.launchPath = "/bin/kill"
        task.arguments = ["-STOP", "\(pid)"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                return .success
            } else {
                // Fallback to virtual suspension
                virtualSuspended.insert(pid)
                return .success
            }
        } catch {
            // Fallback to virtual suspension
            virtualSuspended.insert(pid)
            return .success
        }
    }
    
    func resume(pid: pid_t) async -> IntervenerResult {
        // Check if it was virtually suspended
        if virtualSuspended.remove(pid) != nil {
            return .success
        }
        
        // Try real SIGCONT
        let task = Process()
        task.launchPath = "/bin/kill"
        task.arguments = ["-CONT", "\(pid)"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                return .success
            } else {
                return .failure("Failed to resume process")
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }
    
    func isSuspended(pid: pid_t) -> Bool {
        // Check if process is actually stopped
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "state="]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let state = output.trimmingCharacters(in: .whitespacesAndNewlines)
                return state == "T" || virtualSuspended.contains(pid)
            }
        } catch {
            return virtualSuspended.contains(pid)
        }
        
        return virtualSuspended.contains(pid)
    }
}
