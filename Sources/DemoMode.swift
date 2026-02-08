import Foundation

class DemoMode {
    static let shared = DemoMode()

    private var isActive = false
    private var demoRAMPercentage: Int = 88
    private var demoCPUPercentage: Double = 75.0
    private var suspendedPIDs: Set<pid_t> = []

    func activate() {
        isActive = true
        demoRAMPercentage = 88  // Reset to 88% on activation
        demoCPUPercentage = 75.0
        suspendedPIDs.removeAll()
    }

    func deactivate() {
        isActive = false
        demoRAMPercentage = 88
        demoCPUPercentage = 75.0
        suspendedPIDs.removeAll()
    }

    func reduceRAM(by percentage: Int) {
        if isActive {
            demoRAMPercentage = max(10, demoRAMPercentage - percentage)
        }
    }

    func reduceCPU(by percentage: Double) {
        if isActive {
            demoCPUPercentage = max(5.0, demoCPUPercentage - percentage)
        }
    }

    func suspendProcess(pid: pid_t, memoryMB: Double, cpuUsage: Double) {
        guard isActive else { return }
        suspendedPIDs.insert(pid)

        // Reduce RAM based on process memory
        let ramReduction = Int((memoryMB / 1024.0) / 16.0 * 100)  // Convert MB to percentage of 16GB
        reduceRAM(by: ramReduction)

        // Reduce CPU
        reduceCPU(by: cpuUsage)
    }

    func resumeProcess(pid: pid_t, memoryMB: Double, cpuUsage: Double) {
        guard isActive else { return }
        suspendedPIDs.remove(pid)

        // Restore RAM
        let ramIncrease = Int((memoryMB / 1024.0) / 16.0 * 100)
        demoRAMPercentage = min(88, demoRAMPercentage + ramIncrease)

        // Restore CPU
        demoCPUPercentage = min(75.0, demoCPUPercentage + cpuUsage)
    }

    func getRAMUsage() async -> RAMUsage {
        if isActive {
            // Use current demo RAM percentage
            let total: Double = 16.0
            let used = (Double(demoRAMPercentage) / 100.0) * total
            return RAMUsage(used: used, total: total, percentage: demoRAMPercentage)
        }
        return await SystemMonitor.shared.getRAMUsage()
    }
    
    func getCPUUsage() async -> Double {
        if isActive {
            return demoCPUPercentage
        }
        return await SystemMonitor.shared.getCPUUsage()
    }
    
    func getProcessList(mode: IntentMode) async -> [ProcessInfo] {
        if isActive {
            // Return mode-specific demo processes, filtered by suspension status
            let allProcesses: [ProcessInfo]

            switch mode {
            case .build:
                // Build mode: Show dev tools
                allProcesses = [
                    ProcessInfo(id: 10001, pid: 10001, name: "Docker", cpuUsage: 25.0, memoryMB: 3072),
                    ProcessInfo(id: 10002, pid: 10002, name: "node", cpuUsage: 15.0, memoryMB: 1536),
                    ProcessInfo(id: 10003, pid: 10003, name: "Chrome", cpuUsage: 12.0, memoryMB: 2048),
                    ProcessInfo(id: 10004, pid: 10004, name: "Spotify", cpuUsage: 3.0, memoryMB: 512),
                    ProcessInfo(id: 10005, pid: 10005, name: "Slack", cpuUsage: 5.0, memoryMB: 768),
                    ProcessInfo(id: 10006, pid: 10006, name: "Xcode", cpuUsage: 8.0, memoryMB: 1024)
                ]

            case .chill:
                // Chill mode: Show media apps
                allProcesses = [
                    ProcessInfo(id: 20001, pid: 20001, name: "Chrome", cpuUsage: 18.0, memoryMB: 2560),
                    ProcessInfo(id: 20002, pid: 20002, name: "Spotify", cpuUsage: 8.0, memoryMB: 896),
                    ProcessInfo(id: 20003, pid: 20003, name: "Netflix", cpuUsage: 12.0, memoryMB: 1024),
                    ProcessInfo(id: 20004, pid: 20004, name: "Discord", cpuUsage: 6.0, memoryMB: 512),
                    ProcessInfo(id: 20005, pid: 20005, name: "Xcode", cpuUsage: 10.0, memoryMB: 1536),
                    ProcessInfo(id: 20006, pid: 20006, name: "Docker", cpuUsage: 15.0, memoryMB: 2048)
                ]

            case .focus:
                // Focus mode: Show mix with distracting apps highlighted
                allProcesses = [
                    ProcessInfo(id: 30001, pid: 30001, name: "Xcode", cpuUsage: 20.0, memoryMB: 2048),
                    ProcessInfo(id: 30002, pid: 30002, name: "VS Code", cpuUsage: 12.0, memoryMB: 1024),
                    ProcessInfo(id: 30003, pid: 30003, name: "Chrome", cpuUsage: 15.0, memoryMB: 2304),
                    ProcessInfo(id: 30004, pid: 30004, name: "Slack", cpuUsage: 8.0, memoryMB: 768),
                    ProcessInfo(id: 30005, pid: 30005, name: "Spotify", cpuUsage: 4.0, memoryMB: 512),
                    ProcessInfo(id: 30006, pid: 30006, name: "Discord", cpuUsage: 6.0, memoryMB: 640)
                ]
            }

            // Filter out suspended processes
            return allProcesses.filter { !suspendedPIDs.contains($0.pid) }
        }
        return await SystemMonitor.shared.getProcessList()
    }

    /// Generates impressive demo cleanup data for presentations
    ///
    /// Creates a realistic mix of cache files with large sizes (~15GB total).
    /// Includes Xcode DerivedData, browser caches, logs, and build artifacts.
    func getDemoCleanupFiles() -> [FileItem] {
        guard isActive else { return [] }

        let now = Date()
        let calendar = Calendar.current

        // Create dates for different age categories
        // Most files should be old enough to delete (>7 days) for impressive demo
        let veryOld = calendar.date(byAdding: .month, value: -6, to: now)!
        let old = calendar.date(byAdding: .month, value: -2, to: now)!
        let recentButDeletable = calendar.date(byAdding: .day, value: -10, to: now)!  // Changed to 10 days
        let recent = calendar.date(byAdding: .day, value: -3, to: now)!  // Only for warnings
        let today = now

        // Xcode DerivedData (5-8GB) - More realistic file sizes
        let xcodeFiles = [
            FileItem(path: "~/Library/Developer/Xcode/DerivedData/AROK-abc123/Build/Intermediates.noindex/AROK.build/Debug/AROK.build/Objects-normal/arm64/ContentView.o", name: "ContentView.o", size: 3_182_944, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "~/Library/Developer/Xcode/DerivedData/AROK-abc123/Logs/Build/Cache.db", name: "Cache.db", size: 187_629_568, createdDate: old, modifiedDate: recentButDeletable, isDirectory: false),
            FileItem(path: "~/Library/Developer/Xcode/DerivedData/SomeOldProject-def456/Build/Products/Debug/App.app", name: "App.app", size: 2_847_293_184, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "~/Library/Developer/Xcode/DerivedData/AnotherProject-ghi789/Index/DataStore/v5/units/", name: "units", size: 1_583_742_976, createdDate: veryOld, modifiedDate: old, isDirectory: false),
            FileItem(path: "~/Library/Developer/Xcode/DerivedData/OldWorkProject-jkl012/Logs/Build/LogStoreManifest.plist", name: "LogStoreManifest.plist", size: 67_108_864, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "~/Library/Developer/Xcode/DerivedData/TestProject-mno345/Build/Intermediates.noindex/ArchiveIntermediates/", name: "ArchiveIntermediates", size: 3_221_225_472, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false)
        ]

        // Browser caches (3-5GB) - Mix of deletable and warnings, realistic sizes
        let browserFiles = [
            FileItem(path: "~/Library/Caches/Google/Chrome/Default/Cache/data_1", name: "data_1", size: 1_397_182_464, createdDate: old, modifiedDate: recentButDeletable, isDirectory: false),
            FileItem(path: "~/Library/Caches/Google/Chrome/Default/Code Cache/js/index-dir/the-real-index", name: "the-real-index", size: 629_145_600, createdDate: recent, modifiedDate: today, isDirectory: false),  // Warning: recent & large
            FileItem(path: "~/Library/Caches/Google/Chrome/Default/Media Cache/data_2", name: "data_2", size: 2_684_354_560, createdDate: old, modifiedDate: recentButDeletable, isDirectory: false),
            FileItem(path: "~/Library/Caches/com.apple.Safari/Cache.db", name: "Cache.db", size: 943_718_400, createdDate: old, modifiedDate: recentButDeletable, isDirectory: false),
            FileItem(path: "~/Library/Caches/Firefox/Profiles/default/cache2/entries/", name: "entries", size: 524_288_000, createdDate: old, modifiedDate: old, isDirectory: false)
        ]

        // npm and package manager caches (2-3GB) - realistic sizes
        let packageFiles = [
            FileItem(path: "~/.npm/_cacache/content-v2/sha512/ab/cd/", name: "sha512", size: 1_677_721_600, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "~/.npm/_cacache/index-v5/", name: "index-v5", size: 268_435_456, createdDate: old, modifiedDate: old, isDirectory: false),
            FileItem(path: "~/.cargo/registry/cache/github.com-1ecc6299db9ec823/", name: "cache", size: 614_891_520, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "~/Library/Caches/Homebrew/downloads/", name: "downloads", size: 872_415_232, createdDate: veryOld, modifiedDate: old, isDirectory: false)
        ]

        // iOS Simulator caches (1-2GB) - realistic sizes
        let simulatorFiles = [
            FileItem(path: "~/Library/Developer/CoreSimulator/Caches/dyld/", name: "dyld", size: 738_197_504, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "~/Library/Developer/CoreSimulator/Devices/ABC-123/data/Library/Caches/", name: "Caches", size: 503_316_480, createdDate: old, modifiedDate: old, isDirectory: false),
            FileItem(path: "~/Library/Developer/CoreSimulator/Caches/com.apple.CoreSimulator.SimRuntime.iOS-17-0/", name: "iOS-17-0", size: 251_658_240, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false)
        ]

        // Logs and temp files (1-2GB) - realistic sizes
        let logFiles = [
            FileItem(path: "~/Library/Logs/DiagnosticReports/Xcode_2024-01-15.crash", name: "Xcode_2024-01-15.crash", size: 18_874_368, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "~/Library/Logs/CoreSimulator/CoreSimulator.log", name: "CoreSimulator.log", size: 293_601_280, createdDate: old, modifiedDate: recentButDeletable, isDirectory: false),
            FileItem(path: "/tmp/com.apple.launchd.xyz123/", name: "xyz123", size: 524_288_000, createdDate: recentButDeletable, modifiedDate: recentButDeletable, isDirectory: false),
            FileItem(path: "/var/folders/zz/zyxvpxvq6csfxvn_n0000000000000/T/TemporaryItems/", name: "TemporaryItems", size: 641_728_512, createdDate: recent, modifiedDate: today, isDirectory: false),  // Warning: recent & large
            FileItem(path: "~/Library/Logs/Xcode/xcodebuild.log", name: "xcodebuild.log", size: 147_849_216, createdDate: old, modifiedDate: old, isDirectory: false)
        ]

        // Small junk files for volume
        let junkFiles = [
            FileItem(path: "~/Desktop/.DS_Store", name: ".DS_Store", size: 6_148, createdDate: recent, modifiedDate: today, isDirectory: false),
            FileItem(path: "~/Documents/.DS_Store", name: ".DS_Store", size: 8_196, createdDate: old, modifiedDate: recent, isDirectory: false),
            FileItem(path: "~/Downloads/.localized", name: ".localized", size: 0, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "/tmp/tempfile.tmp", name: "tempfile.tmp", size: 1_024, createdDate: today, modifiedDate: today, isDirectory: false),
            FileItem(path: "/tmp/build-cache.tmp", name: "build-cache.tmp", size: 45_678_901, createdDate: recent, modifiedDate: recent, isDirectory: false)
        ]

        // Additional 1GB of temp/cache files (cache-delete compliant)
        let additionalCacheFiles = [
            // /tmp files (will match /tmp/ pattern)
            FileItem(path: "/tmp/node-gyp-12345.log", name: "node-gyp-12345.log", size: 123_456_789, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "/tmp/python-build-temp.cache", name: "python-build-temp.cache", size: 89_012_345, createdDate: old, modifiedDate: old, isDirectory: false),
            FileItem(path: "/tmp/webpack-cache-abc123", name: "webpack-cache-abc123", size: 156_789_012, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "/tmp/clang-module-cache-xyz", name: "clang-module-cache-xyz", size: 234_567_890, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),

            // /var/folders temp files (will match /var/folders/ pattern)
            FileItem(path: "/var/folders/zz/abc123/T/com.apple.iChat.temp", name: "com.apple.iChat.temp", size: 45_678_901, createdDate: old, modifiedDate: old, isDirectory: false),
            FileItem(path: "/var/folders/zz/abc123/T/ffmpeg-temp-12345.tmp", name: "ffmpeg-temp-12345.tmp", size: 67_890_123, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "/var/folders/zz/abc123/T/preview-cache.tmp", name: "preview-cache.tmp", size: 34_567_890, createdDate: old, modifiedDate: old, isDirectory: false),

            // Application Support caches (will match /cache/ pattern)
            FileItem(path: "~/Library/Application Support/Google/Chrome/ShaderCache/data_0", name: "data_0", size: 89_012_345, createdDate: old, modifiedDate: recentButDeletable, isDirectory: false),
            FileItem(path: "~/Library/Application Support/Slack/Cache/data_1", name: "data_1", size: 56_789_012, createdDate: old, modifiedDate: old, isDirectory: false),
            FileItem(path: "~/Library/Application Support/Discord/Cache/index", name: "index", size: 23_456_789, createdDate: recent, modifiedDate: recent, isDirectory: false),  // Warning

            // Log files (will match .log extension and /logs/ pattern)
            FileItem(path: "~/Library/Logs/com.apple.xcode.log", name: "com.apple.xcode.log", size: 12_345_678, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "~/Library/Logs/npm-debug.log", name: "npm-debug.log", size: 8_901_234, createdDate: old, modifiedDate: old, isDirectory: false),
            FileItem(path: "~/Library/Logs/brew-install.log", name: "brew-install.log", size: 15_678_901, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),

            // .tmp and .temp files (will match extensions)
            FileItem(path: "~/Downloads/safari-download.tmp", name: "safari-download.tmp", size: 34_567_890, createdDate: old, modifiedDate: old, isDirectory: false),
            FileItem(path: "~/Desktop/~$document-temp.tmp", name: "~$document-temp.tmp", size: 1_234_567, createdDate: recent, modifiedDate: recent, isDirectory: false),
            FileItem(path: "/tmp/install-temp-abc.temp", name: "install-temp-abc.temp", size: 23_456_789, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),

            // .bak and .old files (will match extensions)
            FileItem(path: "~/Documents/project.xcodeproj.bak", name: "project.xcodeproj.bak", size: 12_345_678, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "~/Library/Preferences/com.apple.Xcode.plist.old", name: "com.apple.Xcode.plist.old", size: 456_789, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),

            // Vim swap files (will match .swp extension)
            FileItem(path: "~/Documents/.main.swift.swp", name: ".main.swift.swp", size: 234_567, createdDate: old, modifiedDate: old, isDirectory: false),
            FileItem(path: "/tmp/.vimswap-abc123.swo", name: ".vimswap-abc123.swo", size: 123_456, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),

            // Build artifacts (will match .o, .dSYM extensions and /build/ pattern)
            FileItem(path: "/tmp/build-artifacts/main.o", name: "main.o", size: 4_567_890, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "/tmp/build-artifacts/helper.o", name: "helper.o", size: 3_456_789, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),
            FileItem(path: "~/Library/Developer/Xcode/DerivedData/temp-build/module.dSYM", name: "module.dSYM", size: 23_456_789, createdDate: veryOld, modifiedDate: veryOld, isDirectory: false),

            // Python cache (will match .pyc extension)
            FileItem(path: "/tmp/python-cache/__pycache__/module.pyc", name: "module.pyc", size: 567_890, createdDate: old, modifiedDate: old, isDirectory: false),
            FileItem(path: "/tmp/python-cache/__pycache__/utils.pyc", name: "utils.pyc", size: 345_678, createdDate: old, modifiedDate: old, isDirectory: false),

            // More .DS_Store files everywhere
            FileItem(path: "~/Projects/.DS_Store", name: ".DS_Store", size: 6_148, createdDate: old, modifiedDate: recent, isDirectory: false),
            FileItem(path: "~/Pictures/.DS_Store", name: ".DS_Store", size: 8_196, createdDate: recent, modifiedDate: today, isDirectory: false),
            FileItem(path: "~/Music/.DS_Store", name: ".DS_Store", size: 6_148, createdDate: old, modifiedDate: old, isDirectory: false)
        ]

        // Combine all files (~16GB total now)
        return xcodeFiles + browserFiles + packageFiles + simulatorFiles + logFiles + junkFiles + additionalCacheFiles
    }
}
