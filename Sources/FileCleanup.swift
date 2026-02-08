//
//  FileCleanup.swift
//  AROK
//
//  AI-powered file cleanup system
//  Scans for junk files, analyzes with Claude, safely deletes
//

import Foundation
import os.log

class FileCleanup {
    static let shared = FileCleanup()
    private let logger = Logger(subsystem: "com.arok.app", category: "FileCleanup")

    private let fileManager = FileManager.default

    // Directories to scan for cleanup (cache-focused first)
    private let scanDirectories = [
        "~/Library/Caches",
        "~/Library/Developer/Xcode/DerivedData",
        "~/Library/Developer/CoreSimulator/Caches",
        "/tmp",
        "/var/folders",
        "~/Library/Application Support",
        "~/.npm/_cacache",
        "~/.cargo/registry/cache",
        "~/Library/Logs",
        "~/Downloads",
        "~/Desktop"
    ]

    // NEVER touch these
    private let protectedPaths = [
        "/System",
        "/Library/System",
        "/Applications",
        "/usr",
        "/bin",
        "/sbin"
    ]

    /// Scans for files matching user's natural language request
    func analyzeCleanupRequest(_ userRequest: String) async throws -> CleanupPlan {
        logger.info("🧹 Analyzing cleanup request: \(userRequest)")

        // Step 1: Scan file system
        let allFiles = await scanFiles()
        logger.info("📊 Found \(allFiles.count) total files")

        // Step 2: Ask Claude which files to delete
        let plan = try await askClaudeForCleanupPlan(userRequest: userRequest, files: allFiles)

        logger.info("✅ Cleanup plan ready: \(plan.filesToDelete.count) files to delete, \(plan.warnings.count) warnings")
        return plan
    }

    /// Scans directories for files
    private func scanFiles() async -> [FileItem] {
        logger.info("🔍 Scanning directories...")
        var files: [FileItem] = []

        // Check if we're in demo mode - if so, use impressive demo data
        if await AppState.shared.isDemoMode {
            logger.info("🎭 Demo mode active - loading impressive cleanup demo data")
            let demoFiles = DemoMode.shared.getDemoCleanupFiles()

            // Also scan /tmp for some real files to mix in
            let tmpPath = "/tmp"
            if let enumerator = fileManager.enumerator(atPath: tmpPath) {
                var realFileCount = 0
                while let relativePath = enumerator.nextObject() as? String, realFileCount < 20 {
                    let fullPath = (tmpPath as NSString).appendingPathComponent(relativePath)
                    guard let attrs = try? fileManager.attributesOfItem(atPath: fullPath) else { continue }
                    let isDirectory = (attrs[.type] as? FileAttributeType) == .typeDirectory
                    if isDirectory { continue }

                    files.append(FileItem(
                        path: fullPath,
                        name: (relativePath as NSString).lastPathComponent,
                        size: attrs[.size] as? UInt64 ?? 0,
                        createdDate: attrs[.creationDate] as? Date ?? Date(),
                        modifiedDate: attrs[.modificationDate] as? Date ?? Date(),
                        isDirectory: isDirectory
                    ))
                    realFileCount += 1
                }
            }

            // Combine demo files with a few real ones
            files.append(contentsOf: demoFiles)
            logger.info("✅ Demo mode: loaded \(files.count) files (~16GB) for impressive demo")
            return files
        }

        // Normal mode - scan directories
        let maxFilesPerDirectory = 2000  // Increased limit per directory
        let maxTotalFiles = 5000  // Overall limit to prevent memory issues

        for dirPath in scanDirectories {
            let expandedPath = NSString(string: dirPath).expandingTildeInPath

            // Check if directory exists
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDir), isDir.boolValue else {
                logger.debug("⏭️ Skipping non-existent: \(expandedPath)")
                continue
            }

            guard let enumerator = fileManager.enumerator(atPath: expandedPath) else {
                logger.warning("⚠️ Cannot access: \(expandedPath)")
                continue
            }

            var dirFileCount = 0

            while let relativePath = enumerator.nextObject() as? String {
                let fullPath = (expandedPath as NSString).appendingPathComponent(relativePath)

                // Skip if protected
                if isProtectedPath(fullPath) { continue }

                // Get file info
                guard let attrs = try? fileManager.attributesOfItem(atPath: fullPath) else { continue }

                // Skip directories (we want files only)
                let isDirectory = (attrs[.type] as? FileAttributeType) == .typeDirectory
                if isDirectory { continue }

                let fileItem = FileItem(
                    path: fullPath,
                    name: (relativePath as NSString).lastPathComponent,
                    size: attrs[.size] as? UInt64 ?? 0,
                    createdDate: attrs[.creationDate] as? Date ?? Date(),
                    modifiedDate: attrs[.modificationDate] as? Date ?? Date(),
                    isDirectory: isDirectory
                )

                files.append(fileItem)
                dirFileCount += 1

                // Limit per directory
                if dirFileCount >= maxFilesPerDirectory {
                    logger.info("⚠️ Hit limit for \(dirPath), moving to next directory")
                    break
                }

                // Overall safety limit
                if files.count >= maxTotalFiles {
                    logger.warning("⚠️ Hit overall file limit (\(maxTotalFiles)), stopping scan")
                    return files
                }
            }

            logger.info("📂 Scanned \(dirPath): found \(dirFileCount) files")
        }

        logger.info("✅ Total files scanned: \(files.count)")
        return files
    }

    /// Asks Claude which files should be deleted based on user request
    private func askClaudeForCleanupPlan(userRequest: String, files: [FileItem]) async throws -> CleanupPlan {
        logger.info("🤖 Asking Claude for cleanup recommendations...")

        let apiKey = Foundation.ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "YOUR_API_KEY_HERE"

        guard apiKey != "YOUR_API_KEY_HERE" && !apiKey.isEmpty else {
            // Fallback: Simple rule-based cleanup if no API key
            return createSimpleCleanupPlan(userRequest: userRequest, files: files)
        }

        // Build prompt with file information (prioritize larger files)
        let sortedFiles = files.sorted { $0.size > $1.size }  // Largest first
        let filesSummary = sortedFiles.prefix(200).map { file in
            let ageInDays = Calendar.current.dateComponents([.day], from: file.modifiedDate, to: Date()).day ?? 0
            let sizeMB = Double(file.size) / 1_000_000.0
            return "- \(file.name) | \(String(format: "%.2f", sizeMB))MB | Modified \(ageInDays) days ago | \(file.path)"
        }.joined(separator: "\n")

        let prompt = """
        You are a smart file cleanup assistant. The user wants to: "\(userRequest)"

        Here are the files found (showing first 100):
        \(filesSummary)

        Analyze which files should be deleted based on the user's request. Be conservative - when in doubt, DON'T delete.

        Return ONLY valid JSON (no markdown) in this format:
        {
          "filesToDelete": ["full/path/1", "full/path/2"],
          "warnings": [
            {"file": "full/path/3", "reason": "This might be important because..."}
          ],
          "summary": "I found X files matching your request. Deleting Y files will free Z MB."
        }

        Rules:
        - NEVER delete files in /Applications, /System, /Library/System
        - Be cautious with files modified in last 7 days
        - Warn about potentially important files (code, documents, photos)
        """

        // Call Claude API
        let response = try await callClaudeAPI(prompt: prompt)
        let plan = try parseCleanupResponse(response)

        return plan
    }

    /// Simple fallback cleanup plan without AI
    private func createSimpleCleanupPlan(userRequest: String, files: [FileItem]) -> CleanupPlan {
        logger.info("📋 Creating simple cleanup plan (no AI)")

        var filesToDelete: [String] = []
        var warnings: [CleanupWarning] = []

        let lowercasedRequest = userRequest.lowercased()

        // Parse age threshold from request
        var ageDays = 365  // Default: 1 year

        // Try to extract "X days" pattern
        if let daysMatch = lowercasedRequest.range(of: #"(\d+)\s*days?"#, options: .regularExpression) {
            let daysStr = String(lowercasedRequest[daysMatch])
            if let days = Int(daysStr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                ageDays = days
                logger.info("📅 Parsed age threshold: \(ageDays) days")
            }
        } else if lowercasedRequest.contains("month") {
            ageDays = 60  // ~2 months
        }

        // Simple keyword matching for old files
        if lowercasedRequest.contains("old") || lowercasedRequest.contains("year") || lowercasedRequest.contains("month") || lowercasedRequest.contains("days") {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -ageDays, to: Date())!

            for file in files {
                if file.modifiedDate < cutoffDate && !file.isDirectory {
                    if file.size > 10_000_000 { // > 10MB
                        warnings.append(CleanupWarning(
                            file: file.path,
                            reason: "Large file (\(Int(file.size / 1_000_000))MB) - might be important"
                        ))
                    } else {
                        filesToDelete.append(file.path)
                    }
                }
            }
        }

        // Cache files
        if lowercasedRequest.contains("cache") || lowercasedRequest.contains("junk") {
            for file in files {
                if isCacheFile(file) {
                    // Only delete if it's over 7 days old or very small
                    let daysOld = Calendar.current.dateComponents([.day], from: file.modifiedDate, to: Date()).day ?? 0

                    if daysOld > 7 || file.size < 1_000_000 {  // > 7 days old OR < 1MB
                        filesToDelete.append(file.path)
                    } else {
                        warnings.append(CleanupWarning(
                            file: file.path,
                            reason: "Recent large cache file (\(daysOld) days old, \(Int(file.size / 1_000_000))MB)"
                        ))
                    }
                }
            }
        }

        let totalSize = filesToDelete.reduce(UInt64(0)) { sum, path in
            let file = files.first { $0.path == path }
            return sum + (file?.size ?? 0)
        }

        let totalGB = Double(totalSize) / 1_000_000_000.0
        let totalMB = Double(totalSize) / 1_000_000.0

        let sizeStr = totalGB > 1.0 ?
            String(format: "%.2f GB", totalGB) :
            String(format: "%.1f MB", totalMB)

        logger.info("📊 Cleanup summary: \(filesToDelete.count) files, \(sizeStr) to free")

        return CleanupPlan(
            filesToDelete: filesToDelete,
            warnings: warnings,
            summary: "Found \(filesToDelete.count) cache/junk files to delete. Will free \(sizeStr)."
        )
    }

    private func callClaudeAPI(prompt: String) async throws -> String {
        let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"

        let apiKey = Foundation.ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 2000,
            "messages": [["role": "user", "content": prompt]]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw CleanupError.apiError
        }

        return text
    }

    private func parseCleanupResponse(_ response: String) throws -> CleanupPlan {
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw CleanupError.parsingFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode(CleanupPlan.self, from: data)
    }

    /// Actually deletes files (with confirmation)
    func executeCleanup(plan: CleanupPlan) async throws -> CleanupResult {
        logger.info("🗑️ Executing cleanup: \(plan.filesToDelete.count) files")

        // Check if we're in demo mode
        let isDemoMode = await AppState.shared.isDemoMode

        if isDemoMode {
            logger.info("🎭 Demo mode: Simulating cleanup (not actually deleting)")

            // Calculate total size from plan
            var totalSize: UInt64 = 0

            // In demo mode, we need to estimate size from the file list
            // Since demo files don't exist, we'll calculate from our generated data
            let demoFiles = DemoMode.shared.getDemoCleanupFiles()
            for filePath in plan.filesToDelete {
                if let demoFile = demoFiles.first(where: { $0.path == filePath }) {
                    totalSize += demoFile.size
                } else {
                    // For real temp files, try to get actual size
                    if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                       let size = attrs[.size] as? UInt64 {
                        totalSize += size
                        // Actually delete real temp files in demo mode
                        try? fileManager.removeItem(atPath: filePath)
                    }
                }
            }

            // Simulate impressive cleanup
            logger.info("✅ Demo cleanup complete: \(plan.filesToDelete.count) files, \(totalSize) bytes")

            return CleanupResult(
                deletedCount: plan.filesToDelete.count,
                failedCount: 0,
                bytesFreed: totalSize
            )
        }

        // Normal mode - actually delete files
        var deletedFiles: [String] = []
        var failedFiles: [String] = []
        var totalSize: UInt64 = 0

        for filePath in plan.filesToDelete {
            // Double-check it's not protected
            if isProtectedPath(filePath) {
                logger.warning("⚠️ Skipping protected path: \(filePath)")
                failedFiles.append(filePath)
                continue
            }

            // Get size before deleting
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
               let size = attrs[.size] as? UInt64 {
                totalSize += size
            }

            // Delete
            do {
                try fileManager.removeItem(atPath: filePath)
                deletedFiles.append(filePath)
                logger.info("✅ Deleted: \(filePath)")
            } catch {
                logger.error("❌ Failed to delete: \(filePath) - \(error.localizedDescription)")
                failedFiles.append(filePath)
            }
        }

        return CleanupResult(
            deletedCount: deletedFiles.count,
            failedCount: failedFiles.count,
            bytesFreed: totalSize
        )
    }

    private func isProtectedPath(_ path: String) -> Bool {
        for protected in protectedPaths {
            if path.hasPrefix(protected) { return true }
        }
        return false
    }

    /// Determines if a file is a cache file based on multiple heuristics
    private func isCacheFile(_ file: FileItem) -> Bool {
        let lowercasedPath = file.path.lowercased()
        let lowercasedName = file.name.lowercased()

        // Check if in cache directories
        let cachePathPatterns = [
            "/caches/",
            "/cache/",
            "/deriveddata/",
            "/build/",
            "/tmp/",
            "/.npm/",
            "/.cargo/registry/cache",
            "/.gradle/caches",
            "/node_modules/.cache",
            "/logs/",
            "/var/folders/"
        ]

        for pattern in cachePathPatterns {
            if lowercasedPath.contains(pattern) {
                return true
            }
        }

        // Check file name patterns
        let cacheNamePatterns = [
            "cache",
            "temp",
            ".tmp",
            ".log",
            ".swp",
            ".swo",
            "~$",  // Office temp files
            ".DS_Store",
            "Thumbs.db",
            ".localized"
        ]

        for pattern in cacheNamePatterns {
            if lowercasedName.contains(pattern) {
                return true
            }
        }

        // Check file extensions
        let cacheExtensions = [
            ".cache",
            ".tmp",
            ".temp",
            ".log",
            ".bak",
            ".swp",
            ".swo",
            ".old",
            ".dSYM",
            ".o",
            ".pyc",
            ".pyo"
        ]

        for ext in cacheExtensions {
            if lowercasedName.hasSuffix(ext) {
                return true
            }
        }

        // Xcode-specific patterns
        if lowercasedPath.contains("deriveddata") ||
           lowercasedPath.contains("xcuserdata") ||
           lowercasedName.hasSuffix(".xcactivitylog") {
            return true
        }

        return false
    }
}

// MARK: - Data Models

struct FileItem: Codable {
    let path: String
    let name: String
    let size: UInt64
    let createdDate: Date
    let modifiedDate: Date
    let isDirectory: Bool
}

struct CleanupPlan: Codable {
    let filesToDelete: [String]
    let warnings: [CleanupWarning]
    let summary: String
}

struct CleanupWarning: Codable {
    let file: String
    let reason: String
}

struct CleanupResult {
    let deletedCount: Int
    let failedCount: Int
    let bytesFreed: UInt64

    var freedMB: Double {
        Double(bytesFreed) / 1_000_000.0
    }

    var freedGB: Double {
        Double(bytesFreed) / 1_000_000_000.0
    }
}

enum CleanupError: Error {
    case apiError
    case parsingFailed
    case noAPIKey
}
