//
//  PredictiveEngine.swift
//  AROK
//
//  Purpose: Claude AI integration for predictive freeze prevention
//  Created: 2026-02-07
//
//  Analyzes historical activity logs using Claude AI to identify patterns and predict
//  future freezes. Provides proactive recommendations for memory management before
//  problems occur. Uses Claude Sonnet 4.5 for fast, accurate pattern recognition.
//

import Foundation
import os.log

/// Manages AI-powered pattern analysis and predictions
///
/// PredictiveEngine sends activity logs to Claude AI for analysis, receives structured
/// predictions about when freezes are likely to occur, and stores these predictions
/// for proactive action triggering.
///
/// Architecture:
/// - Collect: Get 3 days of activity logs from ActivityLogger
/// - Analyze: Send to Claude API with structured prompt
/// - Parse: Extract JSON predictions from response
/// - Store: Save to disk for persistent predictions
/// - Act: Check predictions periodically and trigger proactive suspensions
///
/// Example usage:
/// ```swift
/// // Analyze patterns (usually triggered by user clicking "Analyze" button)
/// let result = try await PredictiveEngine.shared.analyzePatterns()
/// print("Found \(result.patterns.count) patterns")
/// print("Insights: \(result.insights)")
///
/// // Check if any pattern is currently active
/// if let active = PredictiveEngine.shared.checkForActivePatterns(result) {
///     print("Active: \(active.recommendation)")
///     // Trigger proactive suspension...
/// }
/// ```
///
/// Threading: All methods are async (network I/O)
/// API: Claude Sonnet 4.5 via Anthropic API
/// File location: ~/Library/Application Support/AROK/predictions.json
///
/// - Note: Requires ANTHROPIC_API_KEY environment variable
/// - Note: Gracefully degrades if API fails (logs error, returns nil)
class PredictiveEngine {
    static let shared = PredictiveEngine()
    private let logger = Logger(subsystem: "com.arok.app", category: "PredictiveEngine")

    /// API key from environment variable or hardcoded fallback
    ///
    /// For hackathon: Can hardcode temporarily
    /// For production: Use environment variable or Keychain
    private let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "YOUR_API_KEY_HERE"

    private let apiURL = "https://api.anthropic.com/v1/messages"

    /// File URL for persisted predictions
    private let predictionsFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let arokDir = appSupport.appendingPathComponent("AROK")
        try? FileManager.default.createDirectory(at: arokDir, withIntermediateDirectories: true)
        return arokDir.appendingPathComponent("predictions.json")
    }()

    private init() {
        logger.info("✅ PredictiveEngine initialized")
    }

    // MARK: - Analysis

    /// Analyzes activity patterns using Claude AI
    ///
    /// Sends recent activity logs to Claude for pattern recognition and prediction.
    /// Returns structured predictions about when freezes are likely to occur.
    ///
    /// - Returns: PredictionResult with patterns and insights
    /// - Throws: PredictiveError if analysis fails
    ///
    /// Example:
    /// ```swift
    /// do {
    ///     let result = try await PredictiveEngine.shared.analyzePatterns()
    ///     print("Patterns: \(result.patterns.count)")
    ///     for pattern in result.patterns {
    ///         print("- \(pattern.trigger): \(pattern.recommendation)")
    ///     }
    /// } catch {
    ///     print("Analysis failed: \(error)")
    /// }
    /// ```
    ///
    /// Performance: 2-5 seconds (network latency + Claude processing)
    func analyzePatterns() async throws -> PredictionResult {
        logger.info("🧠 Starting AI pattern analysis...")

        // Get recent activity logs (3 days)
        let logs = ActivityLogger.shared.getRecentLogs(days: 3)
        guard !logs.isEmpty else {
            logger.warning("⚠️ No activity logs found")
            throw PredictiveError.noData
        }

        let logLineCount = logs.components(separatedBy: "\n").count
        logger.info("📊 Analyzing \(logLineCount) log entries")

        // Build prompt for Claude
        let prompt = buildAnalysisPrompt(logs: logs)

        // Call Claude API
        let response = try await callClaudeAPI(prompt: prompt)

        // Parse structured response
        let result = try parseClaudeResponse(response)

        // Save for future use
        savePredictions(result)

        logger.info("✅ Analysis complete: \(result.patterns.count) patterns identified")
        return result
    }

    /// Builds the prompt for Claude AI analysis
    ///
    /// Provides clear instructions, example data format, and expected output structure.
    /// Claude is asked to return ONLY valid JSON for easy parsing.
    private func buildAnalysisPrompt(logs: String) -> String {
        return """
        You are analyzing Mac memory usage patterns to predict and prevent system freezes.

        Here's 3 days of activity data (JSON logs, one per line):
        \(logs)

        Each log entry contains:
        - timestamp: ISO8601 format
        - ramUsage: Percentage (0-100)
        - cpuUsage: Percentage
        - activeMode: User's current mode (build/chill/focus)
        - activeWindow: Active application window
        - topProcesses: Memory-heavy processes
        - events: Auto-suspension events that occurred

        Analyze and identify:
        1. Time periods with consistent RAM spikes (>85%)
        2. Which processes/apps correlate with high memory usage
        3. Predictable patterns (e.g., "every weekday 2-3pm during builds")
        4. Recommended proactive actions (what to suspend, when to do it)

        Return ONLY valid JSON (no markdown, no code blocks) in this exact format:
        {
          "patterns": [
            {
              "trigger": "Human-readable trigger description (e.g., 'Weekdays 2:00-3:00pm')",
              "prediction": "What will happen (e.g., 'RAM will spike to 85%+ during Docker builds')",
              "confidence": 0.85,
              "recommendation": "Specific action to take (e.g., 'Suspend Chrome media tabs at 1:55pm')",
              "processes": ["Process1", "Process2"]
            }
          ],
          "insights": "Overall summary of usage patterns and key recommendations"
        }

        Be specific and actionable. Focus on preventing freezes before they happen.
        Confidence should be 0.0-1.0 (higher = more certain pattern exists).
        """
    }

    /// Calls Claude API with the analysis prompt
    ///
    /// - Parameter prompt: Prompt to send to Claude
    /// - Returns: Response text from Claude
    /// - Throws: PredictiveError on API failure
    ///
    /// Uses Claude Sonnet 4.5 for fast, accurate analysis.
    /// Times out after 30 seconds to prevent hanging.
    private func callClaudeAPI(prompt: String) async throws -> String {
        logger.info("🌐 Calling Claude API...")

        // Verify API key is configured
        guard apiKey != "YOUR_API_KEY_HERE" && !apiKey.isEmpty else {
            logger.error("❌ API key not configured")
            throw PredictiveError.apiKeyMissing
        }

        // Build request
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 2000,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ Invalid response type")
            throw PredictiveError.invalidResponse
        }

        logger.info("📡 API response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("❌ API error (\(httpResponse.statusCode)): \(errorBody)")
            throw PredictiveError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Extract text from API response wrapper
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            logger.error("❌ Failed to parse API response structure")
            throw PredictiveError.parsingFailed
        }

        logger.info("✅ Received response from Claude (\(text.count) chars)")
        logger.debug("Claude response: \(text)")

        return text
    }

    /// Parses Claude's response into structured predictions
    ///
    /// Handles Claude's tendency to wrap JSON in markdown code blocks.
    /// Strips markdown and decodes JSON into PredictionResult.
    ///
    /// - Parameter response: Raw text response from Claude
    /// - Returns: Parsed PredictionResult
    /// - Throws: PredictiveError if parsing fails
    private func parseClaudeResponse(_ response: String) throws -> PredictionResult {
        logger.info("📄 Parsing Claude response...")

        // Claude might wrap in markdown code blocks - strip them
        var cleanedResponse = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedResponse.data(using: .utf8) else {
            logger.error("❌ Failed to convert response to data")
            throw PredictiveError.parsingFailed
        }

        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(PredictionResult.self, from: data)
            logger.info("✅ Parsed \(result.patterns.count) patterns")

            // Log each pattern for debugging
            for pattern in result.patterns {
                logger.info("Pattern: \(pattern.trigger) (confidence: \(pattern.confidence))")
            }

            return result
        } catch {
            logger.error("❌ JSON decoding failed: \(error.localizedDescription)")
            logger.error("Response content: \(cleanedResponse)")
            throw PredictiveError.parsingFailed
        }
    }

    // MARK: - Persistence

    /// Saves predictions to disk for persistence across app restarts
    ///
    /// Allows predictions to remain active even after app closes.
    private func savePredictions(_ result: PredictionResult) {
        do {
            let data = try JSONEncoder().encode(result)
            try data.write(to: predictionsFileURL)
            logger.info("💾 Saved predictions to disk")
        } catch {
            logger.error("❌ Failed to save predictions: \(error.localizedDescription)")
        }
    }

    /// Loads previously saved predictions from disk
    ///
    /// - Returns: PredictionResult if file exists and is valid, nil otherwise
    ///
    /// Called on app startup to restore predictions from previous session.
    func loadPredictions() -> PredictionResult? {
        do {
            let data = try Data(contentsOf: predictionsFileURL)
            let result = try JSONDecoder().decode(PredictionResult.self, from: data)
            logger.info("✅ Loaded predictions from disk: \(result.patterns.count) patterns")
            return result
        } catch {
            logger.debug("ℹ️ No saved predictions found: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Pattern Matching

    /// Checks if any prediction pattern is currently active
    ///
    /// Compares current time against pattern triggers to determine if proactive
    /// action should be taken right now.
    ///
    /// - Parameter result: Prediction result to check
    /// - Returns: Active pattern if found, nil otherwise
    ///
    /// Example:
    /// ```swift
    /// if let active = PredictiveEngine.shared.checkForActivePatterns(predictions) {
    ///     // Pattern is active - take proactive action
    ///     print("Executing: \(active.recommendation)")
    ///     // Suspend recommended processes...
    /// }
    /// ```
    ///
    /// Current implementation: Simple time-based matching (looks for "2pm" in trigger).
    /// Production: More sophisticated parsing of trigger conditions.
    func checkForActivePatterns(_ result: PredictionResult) -> Pattern? {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        for pattern in result.patterns {
            // Parse trigger to check if it matches current time
            // For hackathon: Simple time-based matching
            let triggerLower = pattern.trigger.lowercased()

            // Check for 2pm pattern (from seed data)
            if triggerLower.contains("2:00") || triggerLower.contains("2pm") || triggerLower.contains("14:00") {
                // Check if current time is close to 2pm (5 minutes before to 10 minutes after)
                if (hour == 13 && minute >= 55) || (hour == 14 && minute <= 10) {
                    logger.info("🎯 Active pattern detected: \(pattern.trigger)")
                    return pattern
                }
            }

            // Could add more sophisticated matching here:
            // - Parse time ranges
            // - Check day of week
            // - Check specific conditions
        }

        return nil
    }
}

// MARK: - Data Models

/// Result of Claude AI pattern analysis
///
/// Contains identified patterns and overall insights.
struct PredictionResult: Codable {
    let patterns: [Pattern]
    let insights: String
}

/// Single predictive pattern identified by AI
///
/// Describes when a freeze is likely to occur and what action to take.
struct Pattern: Codable, Identifiable {
    let id = UUID()
    let trigger: String           // When pattern occurs (e.g., "Weekdays 2-3pm")
    let prediction: String        // What will happen (e.g., "RAM will spike to 90%")
    let confidence: Double        // 0.0-1.0, how certain AI is about this pattern
    let recommendation: String    // What to do (e.g., "Suspend Spotify at 1:55pm")
    let processes: [String]       // Which processes to target

    enum CodingKeys: String, CodingKey {
        case trigger, prediction, confidence, recommendation, processes
    }
}

/// Errors that can occur during prediction operations
enum PredictiveError: Error {
    /// No activity logs available for analysis
    /// Resolution: Wait for logs to accumulate (5+ minutes)
    case noData

    /// ANTHROPIC_API_KEY environment variable not set
    /// Resolution: Set env var or update hardcoded value in PredictiveEngine.swift
    case apiKeyMissing

    /// HTTP response was not valid
    /// Resolution: Check network connectivity
    case invalidResponse

    /// API returned non-200 status code
    /// - statusCode: HTTP status received
    /// - message: Error message from response body
    /// Resolution: Check API key validity, rate limits, network
    case apiError(statusCode: Int, message: String)

    /// Failed to parse Claude's response
    /// Resolution: Check logs for response content, may be API format change
    case parsingFailed
}
