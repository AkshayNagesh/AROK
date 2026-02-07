# Claude API Integration Guide

## Overview

AROK uses Claude AI (Sonnet 4.5) to analyze historical activity patterns and predict future memory freezes. This enables proactive memory management by suspending processes before problems occur, rather than reacting after freezes happen.

---

## Setup

### API Key Configuration

**Method 1: Environment Variable (Recommended)**
```bash
export ANTHROPIC_API_KEY="sk-ant-api03-YOUR-KEY-HERE"
```

Add to your shell profile for persistence:
```bash
# ~/.zshrc or ~/.bash_profile
export ANTHROPIC_API_KEY="sk-ant-api03-YOUR-KEY-HERE"
```

Then launch AROK:
```bash
open -a AROK.app
```

**Method 2: Hardcode (Hackathon Only - NOT for production)**

Edit `Sources/PredictiveEngine.swift`:
```swift
private let apiKey = "sk-ant-api03-YOUR-KEY-HERE"  // Replace YOUR_API_KEY_HERE
```

⚠️ **Warning**: Never commit API keys to git! Add `.env` to `.gitignore`.

### Getting an API Key

1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Sign up or log in
3. Navigate to API Keys section
4. Create new key
5. Copy and save securely

---

## How It Works

### 1. Data Collection

ActivityLogger records system state every 5 minutes:
```json
{
  "timestamp": "2026-02-07T14:23:00Z",
  "ramUsage": 87,
  "cpuUsage": 65.5,
  "activeMode": "build",
  "activeWindow": "Terminal - docker compose up",
  "topProcesses": ["Docker", "node", "Chrome"],
  "events": ["Auto-suspended Spotify"]
}
```

Stored as line-delimited JSON in: `~/Library/Application Support/AROK/activity.log`

### 2. Analysis Trigger

User clicks "Analyze" button in AROK UI → triggers `PredictiveEngine.analyzePatterns()`

### 3. API Call

**Request to Claude:**
```http
POST https://api.anthropic.com/v1/messages
Headers:
  anthropic-version: 2023-06-01
  x-api-key: sk-ant-...
  content-type: application/json

Body:
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 2000,
  "messages": [{
    "role": "user",
    "content": "[Prompt with activity logs]"
  }]
}
```

**Prompt Structure:**
- Instructions: What to analyze
- Data: 3 days of activity logs (line-delimited JSON)
- Format: Exact JSON structure required
- Focus: Actionable predictions for freeze prevention

### 4. Response Parsing

Claude returns structured JSON:
```json
{
  "patterns": [
    {
      "trigger": "Weekdays 2:00-3:00pm",
      "prediction": "RAM will spike to 85%+ during Docker builds",
      "confidence": 0.92,
      "recommendation": "Suspend Chrome media tabs at 1:55pm",
      "processes": ["Chrome", "Spotify"]
    }
  ],
  "insights": "User consistently runs heavy builds with Docker + Node in afternoon. Chrome stays open with 20+ tabs."
}
```

### 5. Storage & Activation

Predictions saved to: `~/Library/Application Support/AROK/predictions.json`

Every 60 seconds, AppState checks if current time matches any pattern trigger.
If match found → proactively suspend recommended processes.

---

## API Details

### Model Selection

**Claude Sonnet 4.5** (`claude-sonnet-4-5-20250929`)
- **Why**: Best balance of speed, accuracy, and cost
- **Alternatives**:
  - Haiku 4.5: Faster, cheaper, less accurate (not recommended)
  - Opus 4.6: More accurate, slower, more expensive (overkill)

### Pricing (as of Feb 2026)

| Model | Input | Output | Est. Cost per Analysis |
|-------|-------|--------|------------------------|
| Sonnet 4.5 | $3/MTok | $15/MTok | $0.10-0.20 |
| Haiku 4.5 | $0.80/MTok | $4/MTok | $0.03-0.05 |
| Opus 4.6 | $15/MTok | $75/MTok | $0.50-1.00 |

**Typical analysis**: ~10K input tokens, ~500 output tokens

### Rate Limits

- **Tier 1** (new accounts): 50 requests/min, 40K tokens/min
- **Tier 2**: 1000 requests/min, 80K tokens/min
- **Tier 3**: 2000 requests/min, 160K tokens/min

AROK's usage: ~1 request per user-initiated analysis (not continuous)

### Timeout

- Set to 30 seconds
- Typical response: 2-5 seconds
- Fails gracefully on timeout

---

## Error Handling

### No API Key
**Symptom**: "API key not configured" notification
**Fix**: Set `ANTHROPIC_API_KEY` environment variable

### Invalid API Key
**Symptom**: HTTP 401 error
**Fix**: Check key is correct, not expired, has sufficient credits

### Rate Limit Exceeded
**Symptom**: HTTP 429 error
**Solution**: Wait and retry. AROK logs error but doesn't crash.

### Network Failure
**Symptom**: Connection timeout
**Solution**: Check internet connectivity. AROK continues functioning without predictions.

### Invalid Response Format
**Symptom**: "Failed to parse API response"
**Debug**: Check logs for full response content
**Possible Causes**:
- Claude wrapped JSON in markdown (handled by parser)
- API format changed (rare)
- Malformed prompt

---

## Prompt Engineering

### Current Prompt Strategy

**Key Elements**:
1. **Clear instructions**: What to analyze and why
2. **Data format explanation**: Describe each JSON field
3. **Expected output structure**: Exact JSON schema
4. **Focus directive**: "Be specific and actionable"
5. **Format constraint**: "Return ONLY valid JSON (no markdown)"

**Why This Works**:
- Claude Sonnet 4.5 excels at structured output
- Explicit schema prevents parsing errors
- Action-oriented focus yields practical recommendations

### Customization

To modify analysis focus, edit `buildAnalysisPrompt()` in `PredictiveEngine.swift`:

```swift
private func buildAnalysisPrompt(logs: String) -> String {
    return """
    You are analyzing Mac memory usage patterns...

    // Add custom instructions here:
    Focus on patterns that occur during work hours (9am-6pm).
    Prioritize recommendations that don't disrupt active development work.

    // Rest of prompt...
    """
}
```

---

## Testing

### Test Without Real API Calls

**Option 1: Mock PredictiveEngine**

Create `MockPredictiveEngine.swift`:
```swift
class MockPredictiveEngine {
    func analyzePatterns() async throws -> PredictionResult {
        // Return hardcoded test data
        return PredictionResult(
            patterns: [
                Pattern(
                    trigger: "Weekdays 2pm",
                    prediction: "RAM spike expected",
                    confidence: 0.85,
                    recommendation: "Suspend Chrome tabs",
                    processes: ["Chrome"]
                )
            ],
            insights: "Test insights"
        )
    }
}
```

**Option 2: Use Seed Data**

Activity log seed data already creates patterns Claude can identify:
- Weekday afternoons (2-3pm): Consistent RAM spikes
- Docker + Node + Chrome combination
- Frequent auto-suspend events

Run real analysis on seed data to see Claude's output.

### Validate Response Format

```bash
# After running analysis, check saved predictions:
cat ~/Library/Application\ Support/AROK/predictions.json | jq

# Should show:
# {
#   "patterns": [...],
#   "insights": "..."
# }
```

---

## Performance

### Latency Breakdown

| Stage | Time | Notes |
|-------|------|-------|
| Data collection | <1ms | Read from local file |
| API request | 2-5s | Network + Claude processing |
| Response parsing | <10ms | JSON decode |
| **Total** | **2-5s** | User sees loading spinner |

### Optimization Strategies

**Current**:
- Single API call per analysis
- Caches predictions to disk
- Only re-analyzes on user request

**Future**:
- Incremental analysis (analyze only new logs)
- Background analysis (trigger automatically)
- Streaming responses (show insights as they arrive)

---

## Privacy & Security

### Data Sent to Claude

**Included**:
- System metrics (RAM%, CPU%)
- Process names
- Window titles
- Timestamps

**NOT Included**:
- Process arguments or data
- File contents
- User identification
- Personal information

### Data Retention

**Anthropic's Policy**:
- API requests logged for 30 days (for abuse prevention)
- Not used for model training (opt-in required)
- GDPR compliant

**AROK's Storage**:
- Activity logs: Local only (`~/Library/Application Support/AROK/`)
- Predictions: Local only (no external transmission except initial API call)

---

## Future Enhancements

### Short-term
- Automatic analysis (trigger daily, not just on-demand)
- Pattern confidence thresholds (only act on high-confidence predictions)
- Multiple prediction strategies (time-based, event-based, etc.)

### Medium-term
- Fine-tuned Claude model (train on user-specific patterns)
- Local LLM option (Ollama) for offline operation
- Multi-day trend analysis (weekly patterns)

### Long-term
- Collaborative learning (anonymized pattern sharing across users)
- Predictive charts (visualize predicted vs actual RAM usage)
- Integration with macOS Shortcuts for automation

---

## Troubleshooting

### "No activity logs found"

**Cause**: ActivityLogger hasn't recorded enough data yet
**Solution**: Wait 5-10 minutes for logs to accumulate, or check seed data was generated

```bash
# Verify logs exist
cat ~/Library/Application\ Support/AROK/activity.log | head -5

# Should show JSON entries
```

### "API request timeout"

**Cause**: Network slow or Claude API overloaded
**Solutions**:
- Check internet connection
- Try again in a few minutes
- Increase timeout in `PredictiveEngine.swift`:
  ```swift
  request.timeoutInterval = 60  // Default: 30
  ```

### Predictions Don't Trigger

**Cause**: Pattern trigger doesn't match current conditions
**Debug**:
```bash
# Check saved predictions
cat ~/Library/Application\ Support/AROK/predictions.json | jq '.patterns[].trigger'

# Check logs for pattern matching
log stream --predicate 'subsystem == "com.arok.app" AND category == "PredictiveEngine"'
```

**Solution**: Pattern matching in `checkForActivePatterns()` is basic (looks for "2pm"). Enhance matching logic for your patterns.

---

## Code References

- **PredictiveEngine**: [PredictiveEngine.swift](Sources/PredictiveEngine.swift)
- **AppState integration**: [AppState.swift:analyzePatternsWithAI](Sources/AppState.swift)
- **UI**: [ContentView.swift:predictionsView](Sources/ContentView.swift)
- **Activity logging**: [ActivityLogger.swift](Sources/ActivityLogger.swift)
