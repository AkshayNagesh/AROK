//
//  BrowserManager.swift
//  AROK
//
//  Purpose: Detects and manages browser tabs across Chromium browsers
//  Created: 2026-02-07
//
//  Provides cross-browser tab detection using AppleScript, categorizes tabs by type
//  (media, dev, social, docs), and enables bulk suspension for memory management.
//  Supports all major Chromium-based browsers with identical AppleScript interfaces.
//

import Foundation
import os.log

/// Manages browser tab detection and suspension across Chromium browsers
///
/// BrowserManager detects running Chromium browsers (Chrome, Brave, Edge, Opera, Vivaldi),
/// retrieves all open tabs via AppleScript, categorizes them by content type, and provides
/// suspension capabilities for memory management.
///
/// Architecture:
/// - Detection: Uses `ps` to find running browser processes
/// - Retrieval: AppleScript queries each browser for tab URLs and titles
/// - Categorization: Pattern matching on URLs to classify tab types
/// - Suspension: Closes tabs via AppleScript (simpler than discard API for hackathon)
///
/// Example usage:
/// ```swift
/// let tabs = BrowserManager.shared.getAllTabs()
/// let categorized = BrowserManager.shared.categorizeTabs(tabs)
/// print("Found \(categorized.media.count) media tabs")
///
/// let result = BrowserManager.shared.suspendTabs(categorized.media)
/// print("Suspended \(result.suspendedCount) tabs, freed ~\(result.estimatedRAMFreed)GB")
/// ```
///
/// Threading: All methods are synchronous and blocking (AppleScript limitation)
/// Permissions: Requires Accessibility permission for AppleScript
///
/// - Note: AppleScript is slow (1-2 seconds for 50+ tabs) but works without extensions
/// - Note: Future enhancement: Chrome Native Messaging API for better performance
class BrowserManager {
    static let shared = BrowserManager()
    private let logger = Logger(subsystem: "com.arok.app", category: "BrowserManager")

    /// List of supported Chromium browsers
    ///
    /// All use identical AppleScript API, only app name differs.
    /// Firefox uses different API and is not currently supported.
    private let chromiumBrowsers = [
        "Google Chrome",
        "Brave Browser",
        "Microsoft Edge",
        "Opera",
        "Vivaldi"
    ]

    private init() {
        logger.info("✅ BrowserManager initialized")
    }

    // MARK: - Tab Detection

    /// Retrieves all tabs from all running Chromium browsers
    ///
    /// Detects which browsers are running, then queries each one for its tab list.
    /// Failures for individual browsers are logged but don't block other browsers.
    ///
    /// - Returns: Array of BrowserTab objects (may be empty if no browsers running)
    ///
    /// Example:
    /// ```swift
    /// let tabs = BrowserManager.shared.getAllTabs()
    /// // Returns: [BrowserTab(browser: "Chrome", url: "...", title: "..."), ...]
    /// ```
    ///
    /// Performance: O(browsers × tabs), typically 1-2 seconds for 50+ tabs
    func getAllTabs() -> [BrowserTab] {
        logger.info("🔍 Starting browser tab detection...")
        var allTabs: [BrowserTab] = []

        // First, detect which browsers are currently running
        let runningBrowsers = getRunningBrowsers()
        logger.info("Found \(runningBrowsers.count) running browsers: \(runningBrowsers.joined(separator: ", "))")

        // Query each running browser for its tabs
        for browser in runningBrowsers {
            do {
                let tabs = try getTabsForBrowser(browser)
                allTabs.append(contentsOf: tabs)
                logger.info("✅ Retrieved \(tabs.count) tabs from \(browser)")
            } catch {
                // Log but don't fail - other browsers may still work
                logger.error("❌ Failed to get tabs from \(browser): \(error.localizedDescription)")
            }
        }

        logger.info("📊 Total tabs detected: \(allTabs.count)")
        return allTabs
    }

    /// Detects which Chromium browsers are currently running
    ///
    /// Uses `ps aux` to check process list for browser names.
    ///
    /// - Returns: Array of browser names that are running
    ///
    /// - Note: Uses simple string matching - may have false positives if other apps
    ///         contain browser names, but this is rare in practice
    private func getRunningBrowsers() -> [String] {
        var running: [String] = []

        for browser in chromiumBrowsers {
            do {
                // Check if browser process is running
                let task = Process()
                task.launchPath = "/bin/ps"
                task.arguments = ["aux"]

                let pipe = Pipe()
                task.standardOutput = pipe

                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                // Simple string matching - if browser name appears in process list, it's running
                if output.contains(browser) {
                    running.append(browser)
                    logger.debug("✓ \(browser) is running")
                }
            } catch {
                logger.error("❌ Error checking for \(browser): \(error.localizedDescription)")
            }
        }

        return running
    }

    /// Retrieves all tabs from a specific browser using AppleScript
    ///
    /// - Parameter browser: Full browser name (e.g., "Google Chrome", "Brave Browser")
    /// - Returns: Array of BrowserTab objects from this browser
    /// - Throws: BrowserError if AppleScript fails
    ///
    /// AppleScript returns nested lists: {{url1, title1}, {url2, title2}}
    /// We iterate with 1-based indexing (AppleScript convention) to extract each tab.
    private func getTabsForBrowser(_ browser: String) throws -> [BrowserTab] {
        logger.debug("Fetching tabs for \(browser)...")

        // AppleScript to get all tabs across all windows
        // Try/catch in AppleScript prevents script failure if browser window is closing
        let script = """
        tell application "\(browser)"
            set tabList to {}
            try
                repeat with w in windows
                    repeat with t in tabs of w
                        set tabInfo to {URL of t, title of t}
                        set end of tabList to tabInfo
                    end repeat
                end repeat
            end try
            return tabList
        end tell
        """

        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            logger.error("❌ Failed to create AppleScript for \(browser)")
            throw BrowserError.scriptCreationFailed
        }

        let output = scriptObject.executeAndReturnError(&error)

        if let error = error {
            logger.error("❌ AppleScript error for \(browser): \(error)")
            throw BrowserError.scriptExecutionFailed(error.description)
        }

        // Parse AppleScript output
        var tabs: [BrowserTab] = []

        // AppleScript returns a list of lists: {{url1, title1}, {url2, title2}}
        // Iterate with 1-based indexing (AppleScript convention)
        for i in 1...output.numberOfItems {
            guard let item = output.atIndex(i) else { continue }

            // Each item should have exactly 2 elements: URL and title
            // Skip malformed entries (can happen with special browser windows)
            if item.numberOfItems >= 2 {
                let url = item.atIndex(1)?.stringValue ?? ""
                let title = item.atIndex(2)?.stringValue ?? ""

                let tab = BrowserTab(
                    browser: browser,
                    url: url,
                    title: title
                )
                tabs.append(tab)

                logger.debug("Tab: [\(browser)] \(title) - \(url)")
            }
        }

        return tabs
    }

    // MARK: - Tab Categorization

    /// Categorizes tabs by content type for smart suspension
    ///
    /// Uses pattern matching on URLs to classify tabs into:
    /// - Media: YouTube, Netflix, Spotify, etc.
    /// - Dev: GitHub, StackOverflow, localhost, docs
    /// - Social: Twitter, Facebook, LinkedIn, Discord
    /// - Docs: Google Docs, Notion, Dropbox
    /// - Other: Everything else
    ///
    /// - Parameter tabs: Array of tabs to categorize
    /// - Returns: CategorizedTabs with tabs sorted by type
    ///
    /// Example:
    /// ```swift
    /// let categorized = BrowserManager.shared.categorizeTabs(tabs)
    /// print("Media: \(categorized.media.count)")
    /// print("Dev: \(categorized.dev.count)")
    /// ```
    func categorizeTabs(_ tabs: [BrowserTab]) -> CategorizedTabs {
        logger.info("🏷️ Categorizing \(tabs.count) tabs...")

        var media: [BrowserTab] = []
        var dev: [BrowserTab] = []
        var social: [BrowserTab] = []
        var docs: [BrowserTab] = []
        var other: [BrowserTab] = []

        for tab in tabs {
            let category = categorize(tab)

            switch category {
            case .media:
                media.append(tab)
            case .dev:
                dev.append(tab)
            case .social:
                social.append(tab)
            case .docs:
                docs.append(tab)
            case .other:
                other.append(tab)
            }
        }

        logger.info("📊 Categories - Media: \(media.count), Dev: \(dev.count), Social: \(social.count), Docs: \(docs.count), Other: \(other.count)")

        return CategorizedTabs(
            media: media,
            dev: dev,
            social: social,
            docs: docs,
            other: other
        )
    }

    /// Categorizes a single tab by URL pattern matching
    ///
    /// - Parameter tab: Tab to categorize
    /// - Returns: Category enum value
    ///
    /// Prioritizes categories in order: media, dev, social, docs, other
    /// First match wins, so ordering matters for overlapping patterns.
    private func categorize(_ tab: BrowserTab) -> TabCategory {
        let url = tab.url.lowercased()
        let title = tab.title.lowercased()

        // Media patterns: video streaming, music, entertainment
        let mediaPatterns = [
            "youtube.com", "youtu.be", "twitch.tv", "netflix.com",
            "spotify.com", "crunchyroll.com", "hulu.com", "disney",
            "vimeo.com", "soundcloud.com", "reddit.com/r/videos"
        ]
        if mediaPatterns.contains(where: { url.contains($0) }) {
            return .media
        }

        // Dev patterns: coding resources, documentation, local development
        let devPatterns = [
            "github.com", "stackoverflow.com", "localhost",
            "dev.to", "medium.com/programming", "docs.",
            "api.", "developer.", "gitlab.com"
        ]
        if devPatterns.contains(where: { url.contains($0) }) {
            return .dev
        }

        // Social patterns: social networks, messaging
        let socialPatterns = [
            "twitter.com", "x.com", "facebook.com", "instagram.com",
            "linkedin.com", "discord.com", "slack.com"
        ]
        if socialPatterns.contains(where: { url.contains($0) }) {
            return .social
        }

        // Docs patterns: document editors, cloud storage
        let docsPatterns = [
            "docs.google.com", "notion.so", "dropbox.com",
            "drive.google.com", "overleaf.com"
        ]
        if docsPatterns.contains(where: { url.contains($0) }) {
            return .docs
        }

        // Default: other
        return .other
    }

    // MARK: - Tab Suspension

    /// Suspends (closes) multiple tabs to free memory
    ///
    /// For hackathon: Closes tabs completely (simpler implementation).
    /// Production: Would use chrome.tabs.discard() via extension to keep tabs but unload them.
    ///
    /// - Parameter tabs: Array of tabs to suspend
    /// - Returns: SuspensionResult with count and estimated RAM freed
    ///
    /// Example:
    /// ```swift
    /// let result = BrowserManager.shared.suspendTabs(mediaTabs)
    /// print("Suspended \(result.suspendedCount) tabs")
    /// print("Freed ~\(result.estimatedRAMFreed)GB")
    /// ```
    ///
    /// - Note: Estimate of 150MB per tab is conservative; media tabs often use 300-500MB
    func suspendTabs(_ tabs: [BrowserTab]) -> SuspensionResult {
        logger.info("🛑 Attempting to suspend \(tabs.count) tabs...")

        var suspendedCount = 0
        var estimatedRAMFreed = 0.0

        // Group tabs by browser for efficient processing
        let tabsByBrowser = Dictionary(grouping: tabs, by: { $0.browser })

        for (browser, browserTabs) in tabsByBrowser {
            do {
                try suspendTabsInBrowser(browser, tabs: browserTabs)
                suspendedCount += browserTabs.count
                // Estimate: Each tab = ~150MB (conservative), convert to GB
                estimatedRAMFreed += Double(browserTabs.count) * 0.15
                logger.info("✅ Suspended \(browserTabs.count) tabs in \(browser)")
            } catch {
                logger.error("❌ Failed to suspend tabs in \(browser): \(error.localizedDescription)")
            }
        }

        logger.info("✅ Suspension complete: \(suspendedCount) tabs, ~\(estimatedRAMFreed)GB freed")

        return SuspensionResult(
            suspendedCount: suspendedCount,
            estimatedRAMFreed: estimatedRAMFreed
        )
    }

    /// Suspends tabs in a specific browser
    ///
    /// Closes each tab by matching its URL via AppleScript.
    ///
    /// - Parameters:
    ///   - browser: Browser name
    ///   - tabs: Tabs to close in this browser
    /// - Throws: BrowserError if AppleScript fails
    ///
    /// - Warning: URL matching may fail if tab URL changed since detection
    private func suspendTabsInBrowser(_ browser: String, tabs: [BrowserTab]) throws {
        // For hackathon: Close tabs (simpler than discard API)
        // Production: Use chrome.tabs.discard() via extension

        for tab in tabs {
            // AppleScript to close specific tab by URL
            let script = """
            tell application "\(browser)"
                try
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t is "\(tab.url)" then
                                close t
                            end if
                        end repeat
                    end repeat
                end try
            end tell
            """

            var error: NSDictionary?
            guard let scriptObject = NSAppleScript(source: script) else {
                logger.error("❌ Failed to create close script for tab: \(tab.title)")
                continue
            }

            scriptObject.executeAndReturnError(&error)

            if let error = error {
                logger.warning("⚠️ Failed to close tab '\(tab.title)': \(error)")
            } else {
                logger.debug("✓ Closed tab: \(tab.title)")
            }
        }
    }
}

// MARK: - Data Models

/// Represents a single browser tab
///
/// Identifiable for SwiftUI list rendering, Equatable for comparison.
struct BrowserTab: Identifiable, Equatable {
    let id = UUID()
    let browser: String  // e.g., "Google Chrome"
    let url: String      // Full URL
    let title: String    // Page title
}

/// Tab content categories
enum TabCategory {
    case media   // Video/audio streaming
    case dev     // Development resources
    case social  // Social networks
    case docs    // Document editors
    case other   // Everything else
}

/// Tabs organized by category
///
/// Provides convenient access to tabs by type and aggregate statistics.
struct CategorizedTabs {
    let media: [BrowserTab]
    let dev: [BrowserTab]
    let social: [BrowserTab]
    let docs: [BrowserTab]
    let other: [BrowserTab]

    /// Total count across all categories
    var totalCount: Int {
        media.count + dev.count + social.count + docs.count + other.count
    }

    /// Estimated total RAM usage
    ///
    /// Conservative estimate of 150MB per tab.
    /// Actual usage varies: 50MB for simple pages, 500MB+ for heavy media.
    func estimatedRAM() -> Double {
        return Double(totalCount) * 0.15  // GB
    }
}

/// Result of tab suspension operation
struct SuspensionResult {
    let suspendedCount: Int         // Number of tabs successfully closed
    let estimatedRAMFreed: Double  // Estimated GB freed
}

/// Errors that can occur during browser operations
enum BrowserError: Error {
    /// Failed to create NSAppleScript object
    case scriptCreationFailed

    /// AppleScript execution returned an error
    case scriptExecutionFailed(String)

    /// Browser process not found
    case browserNotRunning
}
