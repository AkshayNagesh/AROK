# AROK Metrics System

## Overview

The metrics system tracks and persists user impact data to demonstrate AROK's value. All metrics are stored locally, automatically persisted across sessions, and displayed in real-time in the UI dashboard.

---

## What We Track

### Primary Metrics

| Metric | Type | Description | Calculation |
|--------|------|-------------|-------------|
| **Freezes Prevented** | Count | Number of times auto-suspend prevented a freeze | Incremented on each auto-suspend event (RAM > 85%) |
| **RAM Saved** | GB (Double) | Total RAM freed by suspending processes | Sum of RAM from all suspended processes (auto + manual) |
| **Processes Suspended** | Count | Total number of processes suspended | Count of all suspension events (auto + manual) |
| **Time Saved** | Minutes | Estimated productivity time saved | Freezes prevented × 5 minutes per freeze |

### Computed Metrics

- **Time Saved Formatted**: Human-readable format (e.g., "2h 15m" or "45m")
- **RAM Saved Formatted**: Display format (e.g., "34.2 GB")

---

## Persistence

### File Location
```
~/Library/Application Support/AROK/metrics.json
```

### File Format
JSON encoding of `MetricsData` struct:
```json
{
  "freezesPrevented": 8,
  "totalRAMSaved": 34.2,
  "processesSuspended": 47,
  "totalTimeSaved": 40,
  "history": [
    {
      "id": "UUID-string",
      "timestamp": "2026-02-07T14:23:00Z",
      "ramUsage": 87,
      "cpuUsage": 65.5,
      "activeMode": "build",
      "event": "Auto-suspended Chrome, Spotify"
    }
  ]
}
```

### Persistence Strategy

- **Automatic**: Metrics save to disk on every change (via `didSet` on `metrics` property)
- **Atomic**: Writes are atomic to prevent corruption
- **Graceful degradation**: Load failures fallback to seed data, save failures are logged but don't crash app
- **First launch**: Seed data is generated automatically for impressive demo

---

## Historical Snapshots

### Purpose
Track system state over time for future charting and trend analysis.

### Data Captured
Each snapshot records:
- **Timestamp**: When the snapshot was taken
- **RAM Usage**: Percentage (0-100)
- **CPU Usage**: Percentage
- **Active Mode**: Current user mode (build/chill/focus)
- **Event**: Optional description of significant events (e.g., "Auto-suspended Chrome")

### Recording Frequency
- **Regular snapshots**: Every 10 minutes (300 update cycles at 2-second intervals)
- **Event snapshots**: Immediately when freeze prevention occurs

### Retention Policy
- Maximum 1000 snapshots stored
- Oldest snapshots automatically removed when limit exceeded
- 1000 snapshots at 10-minute intervals ≈ 7 days of history

---

## Calculations

### 1. Freezes Prevented
```
freezesPrevented += 1
```
**When**: Auto-suspend triggers (RAM > 85%)
**Note**: Manual suspensions don't increment this counter

### 2. RAM Saved
```
totalRAMSaved += ramFreed (in GB)
```
**Sources**:
- Auto-suspend: Sum of memory from all suspended processes
- Manual suspend: Memory from individually suspended process
- Tab suspension: Estimated (tab count × 0.15 GB per tab)

### 3. Time Saved
```
totalTimeSaved += 5 minutes per freeze prevented
```
**Rationale**: Industry estimates suggest each system freeze causes:
- 2-3 minutes waiting for Mac to respond/restart
- 2-3 minutes reloading work and regaining context
- **Total**: ~5 minutes of lost productivity per freeze

### 4. Processes Suspended
```
processesSuspended += count of suspended processes
```
**Includes**: Both auto-suspend and manual suspension events

---

## API Reference

### MetricsManager

#### Properties
```swift
static let shared: MetricsManager
var metrics: MetricsData
```

#### Methods

##### recordFreezePrevented
```swift
func recordFreezePrevented(ramFreedGB: Double, processNames: [String])
```
Records a freeze prevention event from auto-suspend.
**Called by**: `AppState.autoSuspendIfNeeded()`
**Updates**: freezesPrevented, totalRAMSaved, processesSuspended, totalTimeSaved

##### recordManualSuspension
```swift
func recordManualSuspension(processName: String, ramFreedMB: Double)
```
Records a manual process suspension by user.
**Called by**: `AppState.suspendProcess()`
**Updates**: processesSuspended, totalRAMSaved

##### recordSnapshot
```swift
func recordSnapshot(ramUsage: Int, cpuUsage: Double, mode: String)
```
Records a system state snapshot for historical tracking.
**Called by**: `AppState.updateMetrics()` (every 10 minutes)
**Updates**: history array

---

## Integration Points

### AppState Integration

**Auto-Suspend Flow:**
```
1. RAM > 85% detected
2. AIAdvisor scores processes
3. Top 3 candidates suspended
4. MetricsManager.recordFreezePrevented() called
5. NotificationManager generates snarky message
6. User notification displayed
```

**Manual Suspend Flow:**
```
1. User clicks suspend button
2. AppState.suspendProcess() called
3. ProcessIntervener suspends process
4. MetricsManager.recordManualSuspension() called
5. NotificationManager generates message
6. User notification displayed
```

### UI Bindings

ContentView accesses metrics via:
```swift
appState.metrics.freezesPrevented
appState.metrics.ramSavedFormatted
appState.metrics.timeSavedFormatted
appState.metrics.processesSuspended
```

UI updates automatically via `@Published` and SwiftUI's reactive system.

---

## Privacy Considerations

### What's Collected
- Aggregate counts (freezes, processes, totals)
- System metrics (RAM%, CPU%)
- Process names (stored locally only)
- Timestamps

### What's NOT Collected
- No user identification
- No process arguments or data
- No network transmission
- No external analytics

### Data Retention
- All data stays local on user's Mac
- Stored in user's Application Support directory
- User can delete `~/Library/Application Support/AROK/metrics.json` anytime

---

## Demo/Seed Data

### Purpose
Generate realistic metrics on first launch for compelling demos and immediate value display.

### Seed Values
```swift
freezesPrevented: 8
totalRAMSaved: 34.2 GB
processesSuspended: 47
totalTimeSaved: 40 minutes (8 freezes × 5 min)
```

### When Generated
- First app launch (no metrics.json exists)
- Load failure (corrupted file)

---

## Testing

### Verify Persistence
```bash
# Check metrics file exists
ls -la ~/Library/Application\ Support/AROK/metrics.json

# View raw metrics
cat ~/Library/Application\ Support/AROK/metrics.json | jq

# Delete and test seed data
rm ~/Library/Application\ Support/AROK/metrics.json
# Restart AROK - should show seed data
```

### Trigger Events
1. **Auto-suspend**: Use demo mode (CMD+Shift+D) to simulate 88% RAM
2. **Manual suspend**: Click suspend button on any process
3. **Snapshots**: Wait 10 minutes or check logs for "📸 Recorded metrics snapshot"

### View Logs
```bash
log stream --predicate 'subsystem == "com.arok.app" AND category == "Metrics"' --level debug
```

Expected log messages:
- ✅ MetricsManager initialized
- 💾 Saved metrics to disk
- 📊 Recorded freeze prevention
- 📊 Recorded manual suspension
- 📸 Recorded metrics snapshot

---

## Future Enhancements

### Short-term
- Weekly/monthly summaries
- Metrics reset button
- Export metrics to CSV

### Medium-term
- Charts/graphs showing trends over time
- Compare metrics across different modes
- RAM savings by process type

### Long-term
- Machine learning on historical patterns
- Predictive recommendations based on metrics
- Social sharing/leaderboards (opt-in)

---

## Troubleshooting

### Metrics Not Saving
**Symptom**: Changes don't persist across restarts
**Causes**:
1. Disk permissions issue
2. Directory doesn't exist
3. Disk full

**Solutions**:
```bash
# Check directory exists and is writable
ls -la ~/Library/Application\ Support/AROK/
# Should show metrics.json with rw permissions

# Check disk space
df -h

# Check logs for save errors
log show --predicate 'subsystem == "com.arok.app" AND category == "Metrics"' --last 1h | grep "❌"
```

### Metrics Show Zero
**Symptom**: All metrics are 0
**Causes**:
1. Fresh install (expected)
2. Metrics file deleted
3. No events triggered yet

**Solutions**:
- Wait for auto-suspend event (simulate with demo mode)
- Manually suspend a process
- Check that MetricsManager loaded: look for "✅ MetricsManager initialized" in logs

### Metrics Look Wrong
**Symptom**: Numbers seem unrealistic
**Causes**:
1. Seed data still active (first launch)
2. Metrics from previous testing
3. Calculation bug

**Solutions**:
```bash
# Reset metrics (delete file)
rm ~/Library/Application\ Support/AROK/metrics.json
# Restart app

# Check calculations in logs
log show --predicate 'subsystem == "com.arok.app"' --last 1h | grep "📊"
```

---

## Code References

- **MetricsManager**: [MetricsManager.swift](Sources/MetricsManager.swift)
- **AppState integration**: [AppState.swift](Sources/AppState.swift)
- **UI dashboard**: [ContentView.swift:metricsView](Sources/ContentView.swift)
- **Data models**: [MetricsManager.swift:MetricsData](Sources/MetricsManager.swift)
