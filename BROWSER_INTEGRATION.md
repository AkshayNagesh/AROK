# Browser Tab Integration

## Overview

AROK's browser tab management system detects and categorizes open tabs across multiple Chromium-based browsers, providing smart suspension capabilities to reclaim memory. This is particularly valuable since browser tabs are often the largest memory consumers on developer machines.

---

## Supported Browsers

### Chromium-Based (Fully Supported)

| Browser | Detection Name | Status | Notes |
|---------|---------------|--------|-------|
| **Google Chrome** | "Google Chrome" | ✅ Full support | Most common |
| **Brave Browser** | "Brave Browser" | ✅ Full support | Privacy-focused |
| **Microsoft Edge** | "Microsoft Edge" | ✅ Full support | Windows/macOS |
| **Opera** | "Opera" | ✅ Full support | Feature-rich |
| **Vivaldi** | "Vivaldi" | ✅ Full support | Power users |

### Not Supported (Yet)

- **Firefox**: Different AppleScript API, requires separate implementation
- **Safari**: Limited AppleScript capabilities for tab management
- **Arc**: Non-standard architecture

---

## How It Works

### 1. Browser Detection

Uses `ps aux` to check which browsers are currently running:
```bash
ps aux | grep "Google Chrome"
ps aux | grep "Brave Browser"
...
```

Simple string matching determines if browser process exists.

### 2. Tab Retrieval via AppleScript

For each running browser, executes AppleScript to get tabs:
```applescript
tell application "Google Chrome"
    set tabList to {}
    repeat with w in windows
        repeat with t in tabs of w
            set tabInfo to {URL of t, title of t}
            set end of tabList to tabInfo
        end repeat
    end repeat
    return tabList
end tell
```

**Returns**: List of `{URL, Title}` pairs for all tabs

### 3. Tab Categorization

Pattern matching on URLs classifies tabs:

```swift
if url.contains("youtube.com") || url.contains("netflix.com") {
    category = .media
} else if url.contains("github.com") || url.contains("localhost") {
    category = .dev
} else if url.contains("twitter.com") || url.contains("facebook.com") {
    category = .social
} else if url.contains("docs.google.com") || url.contains("notion.so") {
    category = .docs
} else {
    category = .other
}
```

### 4. Tab Suspension

**Current Implementation (Hackathon):**
- Closes tabs completely via AppleScript
- Simpler but tabs are lost

**Future Enhancement:**
- Use `chrome.tabs.discard()` via extension
- Keeps tabs visible but unloads from memory
- Can restore later without losing position

---

## Tab Categories

### Media 🎥
**Purpose**: Video/audio streaming, entertainment
**Patterns**:
- youtube.com, youtu.be
- twitch.tv
- netflix.com, hulu.com, disney
- spotify.com
- crunchyroll.com
- vimeo.com, soundcloud.com

**Typical RAM**: 200-500MB per tab

### Development 💻
**Purpose**: Coding resources, documentation
**Patterns**:
- github.com, gitlab.com
- stackoverflow.com
- localhost (local dev servers)
- dev.to
- docs.* (documentation sites)
- api.*, developer.* (API docs)

**Typical RAM**: 50-150MB per tab

### Social 💬
**Purpose**: Social networks, messaging
**Patterns**:
- twitter.com, x.com
- facebook.com
- instagram.com
- linkedin.com
- discord.com
- slack.com

**Typical RAM**: 100-300MB per tab

### Documents 📄
**Purpose**: Document editors, cloud storage
**Patterns**:
- docs.google.com
- drive.google.com
- notion.so
- dropbox.com
- overleaf.com

**Typical RAM**: 100-200MB per tab

### Other 🌐
**Purpose**: Everything else
**Examples**: News sites, shopping, misc browsing

**Typical RAM**: 50-150MB per tab

---

## Memory Estimation

### Algorithm
```swift
estimatedRAM = tabCount × 150MB
```

**Rationale**:
- Conservative average across all tab types
- Simple pages: 50MB
- Heavy media: 500MB+
- Average: ~150MB

### Accuracy
- ±50% accuracy (rough estimate)
- Actual RAM varies widely:
  - Idle tab: 20-50MB
  - Active YouTube: 300-500MB
  - Heavy web app: 500MB-1GB

**Good enough for hackathon demo**, precise measurement would require browser extension.

---

## API Reference

### BrowserManager

#### Methods

##### getAllTabs()
```swift
func getAllTabs() -> [BrowserTab]
```
Retrieves all tabs from all running Chromium browsers.
**Returns**: Array of tabs (empty if no browsers running)
**Performance**: 1-2 seconds for 50+ tabs

##### categorizeTabs(_ tabs:)
```swift
func categorizeTabs(_ tabs: [BrowserTab]) -> CategorizedTabs
```
Categorizes tabs by content type.
**Returns**: Tabs organized into media/dev/social/docs/other

##### suspendTabs(_ tabs:)
```swift
func suspendTabs(_ tabs: [BrowserTab]) -> SuspensionResult
```
Closes specified tabs to free memory.
**Returns**: Count and estimated RAM freed

### Data Models

#### BrowserTab
```swift
struct BrowserTab {
    let id: UUID          // Unique ID
    let browser: String   // e.g., "Google Chrome"
    let url: String       // Full URL
    let title: String     // Page title
}
```

#### CategorizedTabs
```swift
struct CategorizedTabs {
    let media: [BrowserTab]
    let dev: [BrowserTab]
    let social: [BrowserTab]
    let docs: [BrowserTab]
    let other: [BrowserTab]

    var totalCount: Int
    func estimatedRAM() -> Double  // In GB
}
```

#### SuspensionResult
```swift
struct SuspensionResult {
    let suspendedCount: Int         // Tabs closed
    let estimatedRAMFreed: Double  // GB freed (estimated)
}
```

---

## Usage Examples

### Basic Detection
```swift
// Get all tabs
let tabs = BrowserManager.shared.getAllTabs()
print("Found \(tabs.count) tabs")

// Categorize
let categorized = BrowserManager.shared.categorizeTabs(tabs)
print("Media: \(categorized.media.count)")
print("Dev: \(categorized.dev.count)")
print("Estimated RAM: \(categorized.estimatedRAM())GB")
```

### Suspend Media Tabs
```swift
// In AppState
func suspendMediaTabs() {
    guard let tabs = browserTabs?.media else { return }

    let result = BrowserManager.shared.suspendTabs(tabs)

    // Record metrics
    MetricsManager.shared.recordFreezePrevented(
        ramFreedGB: result.estimatedRAMFreed,
        processNames: ["Browser tabs"]
    )

    // Notify user
    let message = NotificationManager.getSnarkMessage(
        type: .tabsSuspended(count: result.suspendedCount, ramFreed: result.estimatedRAMFreed)
    )
    showNotification(title: "Tabs Suspended", body: message)
}
```

---

## UI Integration

### Browser Tabs Section (ContentView)

**Displays**:
- Icon + "Browser Tabs" header
- Refresh button
- Category rows with counts and color coding
- Estimated total RAM
- "Suspend Media" button (if media tabs exist)

**Layout**:
```
┌────────────────────────────────┐
│ 🌐 Browser Tabs          ↻     │
├────────────────────────────────┤
│ 🎥 Media              [8]      │
│ 💻 Development        [12]     │
│ 💬 Social             [3]      │
│ 📄 Documents          [5]      │
├────────────────────────────────┤
│ Est. RAM: 4.2GB  [Suspend Media]│
└────────────────────────────────┘
```

### Loading State
Shows spinner with "Loading browser tabs..." while detection runs.

---

## Performance Considerations

### AppleScript is Slow
- **1-2 seconds** for 50+ tabs
- Blocking operation (can't be parallelized)
- Runs on background queue to avoid blocking UI

### Mitigation Strategies
1. **Lazy loading**: Load tabs 2 seconds after app launch (let UI settle)
2. **Background queue**: Run detection off main thread
3. **Manual refresh**: User can trigger reload when needed
4. **Caching**: Results stay valid until manual refresh

### When It's Slow
- Many browsers open simultaneously
- 100+ tabs total
- Browser is unresponsive (just launched, heavy load)

**User experience**: Show loading spinner, operation completes in background.

---

## Permissions Required

### Accessibility Permission
**Why**: AppleScript requires Accessibility permission to control other applications.

**How to enable**:
1. System Settings → Privacy & Security → Accessibility
2. Add AROK to allowed apps
3. Toggle on

**What happens without it**:
- AppleScript fails silently
- No tabs detected
- Error logged but app continues

---

## Limitations

### Current Implementation

1. **Tabs are closed, not suspended**
   - Lost on suspension (can't restore)
   - Production would use `chrome.tabs.discard()`

2. **No Firefox support**
   - Different AppleScript API
   - Would need separate implementation

3. **No Safari support**
   - Limited AppleScript capabilities
   - Manual suspension only

4. **Rough memory estimates**
   - ±50% accuracy
   - Would need browser extension for precise measurement

5. **Slow detection**
   - 1-2 seconds for many tabs
   - AppleScript limitation

### Future Enhancements

**Short-term**:
- Add Firefox support
- Better error handling for unresponsive browsers
- Retry logic for transient failures

**Medium-term**:
- Chrome extension for better tab management
- Precise memory measurement
- Tab restoration after suspension
- Scheduled auto-suspension

**Long-term**:
- Safari support via different mechanism
- Cross-platform support (Windows, Linux)
- Smart auto-categorization with AI

---

## Troubleshooting

### No Tabs Detected

**Symptom**: Browser tabs section doesn't appear or shows 0 tabs

**Causes**:
1. No browsers running
2. Accessibility permission not granted
3. Browser just launched (not ready yet)

**Solutions**:
```bash
# Check if browsers are running
ps aux | grep Chrome
ps aux | grep Brave

# Check AROK logs
log stream --predicate 'subsystem == "com.arok.app" AND category == "BrowserManager"'

# Expected: "Found N running browsers" message
```

### AppleScript Errors

**Symptom**: Logs show "❌ AppleScript error"

**Causes**:
1. Browser window closing during detection
2. Browser unresponsive
3. Permissions issue

**Solutions**:
- Wait and retry (use refresh button)
- Restart browser
- Check Accessibility permissions

### Wrong Categorization

**Symptom**: Tab in wrong category (e.g., dev tab marked as media)

**Cause**: URL pattern not matched

**Solution**: Add pattern to BrowserManager.swift:
```swift
// Add to categorize() method
let devPatterns = [
    "github.com",
    "your-new-pattern.com",  // Add here
    ...
]
```

---

## Testing

### Manual Testing
```bash
# 1. Open multiple browsers (Chrome, Brave)
# 2. Open tabs in each category:
#    - youtube.com (media)
#    - github.com (dev)
#    - twitter.com (social)
#    - docs.google.com (docs)

# 3. Launch AROK
# 4. Wait 2 seconds for tab detection
# 5. Verify categories show correct counts

# 6. Test suspension:
#    - Click "Suspend Media"
#    - Verify YouTube tabs close
#    - Verify notification appears
#    - Check metrics increment
```

### View Logs
```bash
# Watch browser detection
log stream --predicate 'category == "BrowserManager"' --level debug

# Expected messages:
# 🔍 Starting browser tab detection...
# Found 2 running browsers: Google Chrome, Brave Browser
# ✅ Retrieved 15 tabs from Google Chrome
# 📊 Total tabs detected: 28
# 🏷️ Categorizing 28 tabs...
# 📊 Categories - Media: 8, Dev: 12, Social: 3, Docs: 5, Other: 0
```

---

## Code References

- **BrowserManager**: [BrowserManager.swift](Sources/BrowserManager.swift)
- **AppState integration**: [AppState.swift:loadBrowserTabs](Sources/AppState.swift)
- **UI**: [ContentView.swift:browserTabsView](Sources/ContentView.swift)
- **Data models**: [BrowserManager.swift:BrowserTab](Sources/BrowserManager.swift)
