import Foundation

class IntentEngine {
    static func score(process: ProcessInfo, mode: IntentMode) -> Double {
        let name = process.name.lowercased()
        
        // Media patterns
        let mediaPatterns = ["chrome", "youtube", "spotify", "anime", "crunchyroll", "netflix", "safari", "firefox", "brave"]
        let isMedia = mediaPatterns.contains { name.contains($0) }
        
        // Dev patterns
        let devPatterns = ["docker", "node", "postgres", "code", "npm", "yarn", "xcode", "git", "terminal", "iterm", "zsh", "bash"]
        let isDev = devPatterns.contains { name.contains($0) }
        
        switch mode {
        case .build:
            // In build mode, suspend media apps (high score = low priority)
            if isMedia {
                return 0.95 // High score = suspend
            }
            if isDev {
                return 0.05 // Low score = keep running
            }
            
        case .chill:
            // In chill mode, suspend dev apps
            if isDev {
                return 0.95 // High score = suspend
            }
            if isMedia {
                return 0.05 // Low score = keep running
            }
            
        case .focus:
            // In focus mode, suspend media apps
            if isMedia {
                return 0.90 // High score = suspend
            }
            if isDev {
                return 0.10 // Low score = keep running
            }
        }
        
        // Default: medium priority
        return 0.5
    }
    
    static func detectModeFromActivity() async -> IntentMode {
        // Get active window title
        if let windowTitle = await SystemMonitor.shared.getActiveWindowTitle() {
            let title = windowTitle.lowercased()
            
            // Check for dev indicators
            if title.contains("xcode") || title.contains("code") || title.contains("terminal") || title.contains("docker") {
                return .build
            }
            
            // Check for media indicators
            if title.contains("youtube") || title.contains("netflix") || title.contains("anime") || title.contains("spotify") {
                return .chill
            }
        }
        
        // Check running processes
        let processes = await SystemMonitor.shared.getProcessList()
        let processNames = processes.map { $0.name.lowercased() }
        
        let devCount = processNames.filter { name in
            ["docker", "node", "xcode", "code"].contains { name.contains($0) }
        }.count
        
        let mediaCount = processNames.filter { name in
            ["chrome", "youtube", "spotify", "safari"].contains { name.contains($0) }
        }.count
        
        if devCount > mediaCount && devCount > 2 {
            return .build
        } else if mediaCount > devCount && mediaCount > 1 {
            return .chill
        }
        
        return .focus
    }
}
