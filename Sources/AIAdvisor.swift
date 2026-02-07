import Foundation

class AIAdvisor {
    static let shared = AIAdvisor()
    
    // For hackathon: Use fast local heuristics instead of API calls
    // This provides 0-latency "AI" scoring based on process patterns
    
    func getProcessScores(processes: [ProcessInfo], mode: IntentMode) async -> [pid_t: Double] {
        // Fast heuristic-based scoring (0 latency)
        var scores: [pid_t: Double] = [:]
        
        for process in processes {
            let baseScore = IntentEngine.score(process: process, mode: mode)
            
            // Enhance with context-aware adjustments
            var adjustedScore = baseScore
            
            // Consider memory usage - high memory processes are better candidates for suspension
            if process.memoryMB > 500 {
                adjustedScore += 0.1
            }
            
            // Consider CPU usage - idle processes are better candidates
            if process.cpuUsage < 1.0 {
                adjustedScore += 0.15
            }
            
            // Consider process name patterns for better context
            let name = process.name.lowercased()
            
            // Background services should be suspended more aggressively
            if name.contains("helper") || name.contains("agent") || name.contains("daemon") {
                adjustedScore += 0.2
            }
            
            // Keep system processes running
            if name.contains("kernel") || name.contains("system") || process.pid < 100 {
                adjustedScore = 0.0
            }
            
            scores[process.pid] = min(adjustedScore, 1.0)
        }
        
        return scores
    }
    
    // Optional: If you want to add real AI later, use this structure
    // But for hackathon, the heuristic approach above is faster and more reliable
    func getProcessScoresFromAPI(processes: [ProcessInfo], mode: IntentMode) async -> [pid_t: Double]? {
        // This would call an API, but for hackathon we skip it
        // Uncomment and implement if you have a fast API endpoint
        
        /*
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            return nil
        }
        
        // Build prompt
        let processNames = processes.map { $0.name }.joined(separator: ", ")
        let prompt = """
        Given mode: \(mode.rawValue)
        Processes: \(processNames)
        Return JSON: {"pid": score} where score 0.0-1.0 (higher = suspend)
        """
        
        // Make API call...
        // For now, return nil to use heuristic fallback
        */
        
        return nil
    }
}
