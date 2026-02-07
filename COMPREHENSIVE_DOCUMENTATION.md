# AROK - Comprehensive Documentation

**Version:** 2.0  
**Last Updated:** February 7, 2026  
**Project Type:** macOS Menu Bar Application  
**Language:** Swift 5.8+  
**Platform:** macOS 14.0+

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Development Journey](#development-journey)
3. [Architecture & Design Decisions](#architecture--design-decisions)
4. [Code Documentation](#code-documentation)
5. [Development Guide](#development-guide)
6. [API Reference](#api-reference)
7. [Troubleshooting](#troubleshooting)
8. [Future Development](#future-development)

---

## Project Overview

### What is AROK?

AROK is an **intent-aware memory governor** for macOS that prevents system freezes by intelligently managing memory allocation based on user activity. Unlike traditional system monitors that only show metrics, AROK proactively suspends low-priority processes before memory pressure causes the system to become unresponsive.

### Core Problem Statement

**Problem:** MacBooks (especially older M1 models) freeze during heavy workloads when running multiple applications simultaneously (Docker, Chrome, VS Code, etc.). The macOS memory management system is "too fair" - it doesn't prioritize based on user intent, leading to system-wide freezes.

**Solution:** AROK acts as a memory governor that:
- Monitors RAM usage in real-time
- Understands user intent through activity detection
- Automatically suspends low-priority processes when memory pressure exceeds 85%
- Provides manual control for fine-tuning
- Works seamlessly in the background via menu bar integration

### Target Audience

- **Primary:** YC founders and developers
- **Secondary:** Anyone doing heavy development work on MacBooks
- **Use Case:** People who run Docker, multiple IDEs, browsers, and media apps simultaneously

### Key Features

1. **Menu Bar Integration** - Native macOS menu bar app (no dock icon)
2. **Real-Time Monitoring** - RAM and CPU usage with color-coded status
3. **Intent-Aware Modes** - Build/Chill/Focus modes optimize memory allocation
4. **Auto-Suspend** - Automatically suspends processes at 85% RAM threshold
5. **Process Control** - Manual suspend/resume for any process
6. **Zero-Latency AI** - Fast heuristic-based process scoring (no API calls)
7. **Demo Mode** - Toggle for presentations (CMD+Shift+D)

---

## Development Journey

### Initial Concept & Planning

The project started with a vision to create a macOS extension app similar to BuhoCleaner, but with intelligent memory management. The initial requirements were:

1. Menu bar app that pops up next to battery icon
2. Shows CPU, temperature, and memory storage
3. Automated system that allocates memory based on user activity
4. Context-aware: understands watching anime vs coding vs school work

### Feasibility Analysis

During planning, we identified several challenges:

#### ✅ **What Works Well:**
- Core concept is viable and demo-friendly
- Layered architecture with fallbacks is solid
- Demo mode is critical for hackathon presentations
- Virtual fallback for SIGSTOP failures is smart

#### ⚠️ **Critical Challenges Identified:**

1. **Temperature Monitoring (HIGH RISK)**
   - macOS doesn't expose CPU temperature via standard APIs
   - Would require kernel extensions or third-party tools
   - **Decision:** Skip temperature monitoring, use CPU load as proxy

2. **Activity Detection (MEDIUM COMPLEXITY)**
   - Detecting "watching anime" vs "coding" is ambiguous
   - **Solution:** Use process names + active window titles
   - Simple heuristics: Chrome with YouTube = media; VS Code = dev

3. **Menu Bar App Architecture**
   - Electron vs Native Swift
   - **Decision:** Native Swift for better performance and integration

#### 🎯 **Strategic Decisions Made:**

1. **Skip Temperature** - Use CPU % as proxy instead
2. **Process-Based Activity Detection** - Use process names + window titles (no AI API needed)
3. **Native Swift** - Better performance, true macOS integration
4. **Zero-Latency AI** - Heuristic-based scoring (no API calls, instant decisions)

### Architecture Decisions

#### Why Native Swift Over Electron?

- **Performance:** No JavaScript bridge overhead
- **Integration:** True macOS menu bar integration
- **Memory:** Lower memory footprint
- **User Experience:** Native look and feel
- **Reliability:** No web view dependencies

#### Why Heuristic AI Over API Calls?

- **Latency:** Instant decisions (0ms vs 100-500ms API calls)
- **Reliability:** Works offline, no network dependency
- **Cost:** No API costs for hackathon demo
- **Privacy:** No data sent to external services

#### Process Suspension Strategy

- **Primary:** SIGSTOP/SIGCONT signals (real process suspension)
- **Fallback:** Virtual suspension (tracked internally if permissions fail)
- **Safety:** Never suspend system processes (PID < 100)
- **User Control:** Manual override always available

---

## Architecture & Design Decisions

### System Architecture

```
┌─────────────────────────────────────────────────┐
│           macOS Menu Bar (NSStatusBar)          │
│         CPU Icon (Green/Yellow/Red)             │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│              AROKApp (AppDelegate)              │
│  - Menu bar setup                               │
│  - Popover management                            │
│  - Keyboard shortcuts (CMD+Shift+D)             │
└─────────────────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ AppState    │ │ContentView  │ │SystemMonitor│
│ (State Mgmt)│ │ (SwiftUI)   │ │ (Metrics)   │
└─────────────┘ └─────────────┘ └─────────────┘
        │             │             │
        └─────────────┼─────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│IntentEngine │ │ProcessInter │ │  AIAdvisor  │
│  (Scoring)  │ │  (Control)  │ │ (Heuristics)│
└─────────────┘ └─────────────┘ └─────────────┘
                      │
                      ▼
            ┌─────────────────┐
            │   DemoMode      │
            │  (Simulation)   │
            └─────────────────┘
```

### Module Responsibilities

#### 1. **AROKApp.swift** - Application Entry Point
- Sets up menu bar status item
- Manages popover (show/hide)
- Handles keyboard shortcuts
- Updates status bar icon color based on RAM usage

#### 2. **AppState.swift** - Central State Management
- Observable object for SwiftUI
- Manages current mode (Build/Chill/Focus)
- Tracks RAM/CPU usage
- Manages process list
- Handles auto-suspend logic
- Manages suspended processes set

#### 3. **ContentView.swift** - User Interface
- SwiftUI view hierarchy
- RAM gauge visualization
- Mode selector buttons
- Process list with suspend/resume controls
- Glassmorphism styling
- Demo mode indicator

#### 4. **SystemMonitor.swift** - System Metrics
- RAM usage via `vm_stat` command
- CPU usage via `top` command
- Process list via `ps` command
- Active window detection via AppleScript
- Caching for offline/error scenarios

#### 5. **ProcessIntervener.swift** - Process Control
- Suspend processes (SIGSTOP)
- Resume processes (SIGCONT)
- Virtual suspension tracking (fallback)
- Process state checking

#### 6. **IntentEngine.swift** - Mode-Based Scoring
- Scores processes based on current mode
- Pattern matching for process names
- Mode definitions (Build/Chill/Focus)
- Activity detection from processes/windows

#### 7. **AIAdvisor.swift** - Enhanced Scoring
- Heuristic-based process scoring
- Context-aware adjustments (memory, CPU, process type)
- Zero-latency decisions
- Extensible for future API integration

#### 8. **DemoMode.swift** - Demo Simulation
- Simulates high memory pressure (88%)
- Provides demo process list
- Toggle via CMD+Shift+D
- Stubs SystemMonitor when active

### Data Flow

```
User Action (Mode Switch)
    │
    ▼
AppState.setMode()
    │
    ▼
IntentEngine.score() ──► AIAdvisor.getProcessScores()
    │                          │
    │                          ▼
    │                    Enhanced Scoring
    │                          │
    └──────────────────────────┘
              │
              ▼
    Auto-Suspend Check (RAM > 85%?)
              │
              ▼
    ProcessIntervener.suspend()
              │
              ▼
    Notification to User
```

### State Management Pattern

AROK uses a **centralized state management** pattern:

- **AppState** is a singleton (`AppState.shared`)
- All SwiftUI views observe `@StateObject` or `@ObservedObject`
- State updates trigger UI refreshes automatically
- Async operations update state on main thread

### Error Handling Strategy

**Defensive Programming Everywhere:**

1. **System Calls:** All wrapped in try/catch
2. **Fallbacks:** Cached values if calls fail
3. **Virtual Suspension:** If SIGSTOP fails, track internally
4. **UI Resilience:** Never show errors to user, always show something
5. **Graceful Degradation:** App works even if some features fail

---

## Code Documentation

### File-by-File Breakdown

#### **AROKApp.swift**

**Purpose:** Application entry point and menu bar setup

**Key Components:**
- `AROKApp`: SwiftUI app struct with `@main` attribute
- `AppDelegate`: NSApplicationDelegate for menu bar integration

**Important Methods:**

```swift
func applicationDidFinishLaunching(_ notification: Notification)
```
- Initializes menu bar status item
- Creates popover with ContentView
- Sets up keyboard shortcuts
- Starts monitoring

```swift
func setupKeyboardShortcuts()
```
- Registers CMD+Shift+D for demo mode
- Fallback to CMD+Shift+N if D is taken
- Global and local event monitors

```swift
func updateStatusBarIcon()
```
- Updates icon color every 2 seconds
- Green (≤70%), Yellow (71-85%), Red (>85%)
- Runs on background timer

**Dependencies:**
- SwiftUI, AppKit, UserNotifications

---

#### **AppState.swift**

**Purpose:** Central state management for the entire app

**Key Properties:**

```swift
@Published var currentMode: IntentMode
```
- Current mode: Build, Chill, or Focus
- Triggers auto-suspend when changed

```swift
@Published var ramUsage: RAMUsage
```
- Current RAM usage (used, total, percentage)
- Updated every 2 seconds

```swift
@Published var processes: [ProcessInfo]
```
- List of processes using >100MB RAM
- Sorted by memory usage descending

```swift
@Published var suspendedProcesses: Set<pid_t>
```
- Set of PIDs that are currently suspended
- Used to show suspend/resume button state

**Key Methods:**

```swift
func setMode(_ mode: IntentMode)
```
- Changes current mode
- Triggers auto-suspend check
- Updates UI automatically

```swift
func autoSuspendIfNeeded() async
```
- Checks if RAM > 85%
- Gets process scores from AIAdvisor
- Suspends top 3 lowest-priority processes
- Shows notification

```swift
func suspendProcess(_ pid: pid_t) async
```
- Calls ProcessIntervener to suspend
- Updates suspendedProcesses set
- Handles errors gracefully

**Data Structures:**

```swift
struct RAMUsage {
    let used: Double    // GB
    let total: Double   // GB
    let percentage: Int // 0-100
}

struct ProcessInfo: Identifiable {
    let id: pid_t
    let pid: pid_t
    let name: String
    let cpuUsage: Double
    let memoryMB: Double
}
```

---

#### **ContentView.swift**

**Purpose:** SwiftUI user interface

**View Hierarchy:**

```
ContentView
├── headerView (Title + Demo Toggle + Settings)
├── ScrollView
│   ├── ramGaugeView (Circular gauge + CPU %)
│   ├── modeSelectorView (Build/Chill/Focus buttons)
│   └── processListView (Process rows with suspend/resume)
└── footerView (Demo mode indicator + version)
```

**Key Components:**

```swift
struct ContentView: View
```
- Main container view
- Uses `@StateObject` to observe AppState
- Glassmorphism background with VisualEffectView

```swift
struct ProcessRow: View
```
- Individual process row
- Shows name, memory, CPU usage
- Suspend/resume button
- Visual indicator if suspended

```swift
struct VisualEffectView: NSViewRepresentable
```
- Wraps NSVisualEffectView for glassmorphism
- Material: `.hudWindow`
- Blending mode: `.behindWindow`

**Styling:**
- Glassmorphism: `.ultraThinMaterial` backgrounds
- Shadows for depth
- Color-coded gauges (green/yellow/red)
- Smooth animations

---

#### **SystemMonitor.swift**

**Purpose:** System metrics collection

**Key Methods:**

```swift
func getRAMUsage() async -> RAMUsage
```
- Executes `vm_stat` command
- Parses output for memory pages
- Calculates used/total/percentage
- Returns cached value on error

**Parsing Logic:**
- Extracts: Pages free, active, inactive, wired
- Calculates page size (usually 4096 bytes)
- Converts to GB and percentage

```swift
func getCPUUsage() async -> Double
```
- Executes `top -l 1 -n 0`
- Parses "CPU usage:" line
- Extracts percentage
- Returns cached value on error

```swift
func getProcessList() async -> [ProcessInfo]
```
- Executes `ps -eo pid,pcpu,rss,comm`
- Parses each line
- Filters processes >100MB RAM
- Sorts by memory usage descending

```swift
func getActiveWindowTitle() async -> String?
```
- Uses AppleScript to get frontmost window
- Returns window title
- Used for activity detection

**Error Handling:**
- All methods return cached values on failure
- Never throws errors
- Silent failures (logged but not shown to user)

---

#### **ProcessIntervener.swift**

**Purpose:** Process suspension and resumption

**Key Methods:**

```swift
func suspend(pid: pid_t) async -> IntervenerResult
```
- Executes `kill -STOP <pid>`
- If fails, adds to virtualSuspended set
- Returns success either way (virtual or real)

**Virtual Suspension:**
- Tracks PIDs in `virtualSuspended` set
- Used when SIGSTOP fails (permissions)
- UI still shows as suspended
- Resume removes from set

```swift
func resume(pid: pid_t) async -> IntervenerResult
```
- Checks if virtually suspended first
- If yes, removes from set
- Otherwise executes `kill -CONT <pid>`
- Returns success/failure

```swift
func isSuspended(pid: pid_t) -> Bool
```
- Checks process state via `ps -p <pid> -o state=`
- State "T" means stopped
- Also checks virtualSuspended set

**Result Type:**

```swift
enum IntervenerResult {
    case success
    case failure(String)
}
```

---

#### **IntentEngine.swift**

**Purpose:** Mode-based process scoring

**Scoring Logic:**

Processes get scores from 0.0 to 1.0:
- **Low score (0.0-0.3):** Keep running (high priority)
- **Medium score (0.4-0.6):** Neutral
- **High score (0.7-1.0):** Suspend (low priority)

**Mode Definitions:**

**Build Mode:**
- Media apps (Chrome, YouTube, Spotify): 0.95 (suspend)
- Dev tools (Docker, Node, VS Code): 0.05 (keep)
- Others: 0.5 (neutral)

**Chill Mode:**
- Dev tools: 0.95 (suspend)
- Media apps: 0.05 (keep)
- Others: 0.5 (neutral)

**Focus Mode:**
- Media apps: 0.90 (suspend)
- Dev tools: 0.10 (keep)
- Others: 0.5 (neutral)

**Pattern Matching:**

```swift
let mediaPatterns = ["chrome", "youtube", "spotify", "anime", ...]
let devPatterns = ["docker", "node", "postgres", "code", ...]
```

**Activity Detection:**

```swift
func detectModeFromActivity() async -> IntentMode
```
- Checks active window title
- Checks running processes
- Returns best-guess mode
- Falls back to Focus mode

---

#### **AIAdvisor.swift**

**Purpose:** Enhanced heuristic-based process scoring

**Scoring Enhancements:**

Base score from IntentEngine is adjusted by:

1. **Memory Usage:**
   - Processes >500MB: +0.1 to score
   - Larger processes = better suspend candidates

2. **CPU Usage:**
   - Processes <1% CPU: +0.15 to score
   - Idle processes = better suspend candidates

3. **Process Type:**
   - Helpers/agents/daemons: +0.2 to score
   - Background services = better suspend candidates

4. **System Protection:**
   - Kernel/system processes: score = 0.0
   - PID < 100: score = 0.0
   - Never suspend system processes

**Future Extensibility:**

```swift
func getProcessScoresFromAPI(...) async -> [pid_t: Double]?
```
- Placeholder for future API integration
- Currently returns nil (uses heuristics)
- Can be extended with OpenAI/Claude API

**Why Heuristics Over API:**

- **Latency:** 0ms vs 100-500ms
- **Reliability:** Works offline
- **Cost:** No API costs
- **Privacy:** No data sent externally

---

#### **DemoMode.swift**

**Purpose:** Demo mode simulation for presentations

**Activation:**

```swift
func activate()
func deactivate()
```
- Toggles `isActive` flag
- Called from AppState.toggleDemoMode()

**Stubbed Methods:**

```swift
func getRAMUsage() async -> RAMUsage
```
- Returns fixed 88% usage (14/16 GB)
- Simulates high memory pressure

```swift
func getCPUUsage() async -> Double
```
- Returns fixed 75% CPU
- Simulates high CPU load

```swift
func getProcessList() async -> [ProcessInfo]
```
- Returns demo processes:
  - demo-worker (1024 MB)
  - Chrome (512 MB)
  - Spotify (256 MB)
  - Docker (2048 MB)

**Usage:**

1. Press CMD+Shift+D
2. RAM gauge shows 88%
3. Process list shows demo processes
4. Auto-suspend triggers (if enabled)
5. Perfect for hackathon demos

---

## Development Guide

### Prerequisites

1. **macOS 14.0+** (Sonoma or later)
2. **Xcode 15.0+** (or latest version)
3. **Swift 5.8+** (comes with Xcode)

### Setup Instructions

#### Step 1: Install Xcode

1. Open Mac App Store
2. Search for "Xcode"
3. Click "Get" or "Install"
4. Wait for download (~15GB)
5. Open Xcode and accept license

#### Step 2: Open Project

```bash
cd /path/to/AROK
open AROK.xcodeproj
```

#### Step 3: Configure Project

1. Select "AROK" target in Xcode
2. Go to "Signing & Capabilities"
3. Select your development team
4. Xcode will create provisioning profile

#### Step 4: Build

- Press `CMD+B` to build
- Check for errors in Issue Navigator

#### Step 5: Run

- Press `CMD+R` to run
- App appears in menu bar (no dock icon)
- Click CPU icon to open popover

### Project Structure

```
AROK/
├── Sources/                    # Swift source files
│   ├── AROKApp.swift          # App entry point
│   ├── AppState.swift         # State management
│   ├── ContentView.swift      # SwiftUI UI
│   ├── SystemMonitor.swift    # System metrics
│   ├── ProcessIntervener.swift # Process control
│   ├── IntentEngine.swift     # Mode scoring
│   ├── AIAdvisor.swift        # Enhanced scoring
│   └── DemoMode.swift         # Demo simulation
├── AROK.xcodeproj/            # Xcode project
├── Info.plist                 # App configuration
├── README.md                  # User docs
├── SETUP.md                   # Setup guide
├── DEMO_SCRIPT.md            # Demo script
└── PROJECT_SUMMARY.md        # Project overview
```

### Building from Command Line

```bash
# Build release version
xcodebuild -project AROK.xcodeproj \
           -scheme AROK \
           -configuration Release \
           clean build

# Output location
# build/Build/Products/Release/AROK.app
```

### Running Tests

Currently no unit tests. To add:

1. Create test target in Xcode
2. Add test files to `Tests/` directory
3. Test SystemMonitor, IntentEngine, etc.

### Code Style

- **Swift Style Guide:** Follow Apple's Swift API Design Guidelines
- **Naming:** camelCase for variables, PascalCase for types
- **Comments:** Document public APIs, complex logic
- **Error Handling:** Always use try/catch, never force unwrap

### Debugging

#### Enable Debug Logging

Add to `SystemMonitor.swift`:

```swift
private let debug = true

func getRAMUsage() async -> RAMUsage {
    if debug { print("Getting RAM usage...") }
    // ...
}
```

#### Xcode Debugger

1. Set breakpoints in code
2. Run with debugger (CMD+R)
3. Inspect variables in Debug Navigator
4. Use LLDB console for commands

#### Common Issues

**Menu bar icon not showing:**
- Check Info.plist has `LSUIElement = YES`
- Verify `NSApp.setActivationPolicy(.accessory)`

**Process suspension not working:**
- Check permissions (may need Accessibility)
- Verify process isn't system process (PID < 100)
- Check virtual suspension fallback

**RAM percentage wrong:**
- Verify `vm_stat` parsing logic
- Check page size calculation
- Add debug logging

---

## API Reference

### AppState API

#### Properties

```swift
@Published var currentMode: IntentMode
```
Current mode (Build, Chill, or Focus)

```swift
@Published var ramUsage: RAMUsage
```
Current RAM usage statistics

```swift
@Published var cpuUsage: Double
```
Current CPU usage percentage (0-100)

```swift
@Published var processes: [ProcessInfo]
```
List of processes using >100MB RAM

```swift
@Published var isDemoMode: Bool
```
Whether demo mode is active

```swift
@Published var suspendedProcesses: Set<pid_t>
```
Set of suspended process PIDs

#### Methods

```swift
func setMode(_ mode: IntentMode)
```
Changes current mode and triggers auto-suspend check

```swift
func toggleDemoMode()
```
Toggles demo mode on/off

```swift
func suspendProcess(_ pid: pid_t) async
```
Suspends a process by PID

```swift
func resumeProcess(_ pid: pid_t) async
```
Resumes a suspended process by PID

```swift
func autoSuspendIfNeeded() async
```
Checks RAM usage and auto-suspends if >85%

---

### SystemMonitor API

#### Methods

```swift
func startMonitoring()
```
Starts the monitoring system

```swift
func getRAMUsage() async -> RAMUsage
```
Returns current RAM usage (used, total, percentage)

```swift
func getCPUUsage() async -> Double
```
Returns current CPU usage percentage

```swift
func getProcessList() async -> [ProcessInfo]
```
Returns list of processes using >100MB RAM

```swift
func getActiveWindowTitle() async -> String?
```
Returns title of currently active window

---

### ProcessIntervener API

#### Methods

```swift
func suspend(pid: pid_t) async -> IntervenerResult
```
Suspends a process (SIGSTOP) or tracks virtually

```swift
func resume(pid: pid_t) async -> IntervenerResult
```
Resumes a suspended process (SIGCONT)

```swift
func isSuspended(pid: pid_t) -> Bool
```
Checks if a process is currently suspended

---

### IntentEngine API

#### Methods

```swift
func score(process: ProcessInfo, mode: IntentMode) -> Double
```
Returns priority score (0.0-1.0) for a process in given mode

```swift
func detectModeFromActivity() async -> IntentMode
```
Attempts to detect current mode from activity

---

### AIAdvisor API

#### Methods

```swift
func getProcessScores(processes: [ProcessInfo], mode: IntentMode) async -> [pid_t: Double]
```
Returns enhanced priority scores for all processes

---

## Troubleshooting

### Build Issues

**Error: "Cannot find type 'X' in scope"**
- Solution: Check all files are added to target
- Clean build folder (Shift+CMD+K)
- Rebuild

**Error: "Command failed with exit code 1"**
- Solution: Check Xcode version compatibility
- Update to latest Xcode
- Check Swift version matches

**Error: "Signing for AROK requires a development team"**
- Solution: Select your Apple ID in Signing & Capabilities
- Or disable code signing for development

### Runtime Issues

**Menu bar icon not appearing:**
- Check `LSUIElement = YES` in Info.plist
- Verify `NSApp.setActivationPolicy(.accessory)`
- Restart app

**Popover not showing:**
- Check status bar item button exists
- Verify popover is created
- Check for errors in console

**RAM percentage always 50%:**
- `vm_stat` parsing may be failing
- Check console for errors
- Verify `vm_stat` command works in Terminal

**Process suspension not working:**
- Some processes require elevated permissions
- System processes (PID < 100) cannot be suspended
- Check virtual suspension fallback is working

**Keyboard shortcut not working:**
- Check for conflicts with other apps
- Try fallback shortcut (CMD+Shift+N)
- Verify event monitor is set up

### Permission Issues

**Accessibility Permission:**
- System Preferences → Security & Privacy → Privacy → Accessibility
- Add AROK.app
- Required for active window detection

**Full Disk Access (Optional):**
- System Preferences → Security & Privacy → Privacy → Full Disk Access
- Add AROK.app
- Improves process detection

### Performance Issues

**High CPU usage:**
- Reduce monitoring frequency (currently 2 seconds)
- Optimize `vm_stat` parsing
- Cache more aggressively

**Memory leaks:**
- Check for retain cycles in closures
- Use `[weak self]` in async closures
- Profile with Instruments

---

## Future Development

### Planned Features

#### 1. **Temperature Monitoring**
- Integrate with SMC (System Management Controller)
- Use `osx-cpu-temp` or similar library
- Show thermal pressure indicator

#### 2. **Real AI Integration**
- Add OpenAI/Claude API integration
- Context-aware process scoring
- Learning from user behavior

#### 3. **Activity Detection Improvements**
- Machine learning for activity classification
- Window content analysis
- Time-based patterns

#### 4. **Disk Cleaner**
- Clean cache directories
- Remove old logs
- Free up disk space

#### 5. **Notifications & Alerts**
- Customizable thresholds
- Sound alerts
- Notification center integration

#### 6. **Statistics & History**
- Memory usage over time
- Process suspension history
- Performance trends

#### 7. **Settings UI**
- Customizable thresholds
- Mode configuration
- Process whitelist/blacklist

#### 8. **Multi-Monitor Support**
- Show on all monitors
- Per-monitor settings

### Code Improvements

#### 1. **Unit Tests**
- Test SystemMonitor parsing
- Test IntentEngine scoring
- Test ProcessIntervener

#### 2. **Error Handling**
- Better error messages
- User-facing error dialogs
- Error logging to file

#### 3. **Performance**
- Optimize process list parsing
- Cache more aggressively
- Background processing

#### 4. **Accessibility**
- VoiceOver support
- Keyboard navigation
- High contrast mode

### Architecture Improvements

#### 1. **Modularization**
- Split into separate frameworks
- Plugin system for modes
- Extensible scoring system

#### 2. **Configuration**
- JSON/YAML config files
- User preferences persistence
- Import/export settings

#### 3. **Logging**
- Structured logging
- Log levels (debug, info, error)
- Log rotation

### Integration Ideas

#### 1. **Shortcuts Integration**
- Siri Shortcuts support
- Automate mode switching
- Voice commands

#### 2. **Widget Support**
- macOS Widget extension
- Show metrics on desktop
- Quick actions

#### 3. **CLI Tool**
- Command-line interface
- Script automation
- Remote control

---

## Contributing

### How to Contribute

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

### Code Review Process

1. All PRs require review
2. Code must compile without warnings
3. Follow Swift style guide
4. Add tests for new features
5. Update documentation

### Reporting Issues

Use GitHub Issues to report:
- Bugs
- Feature requests
- Documentation improvements
- Performance issues

Include:
- macOS version
- Xcode version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

---

## License & Credits

**Copyright © 2026 AROK. All rights reserved.**

### Credits

- Built for YC Hackathon 2026
- Inspired by BuhoCleaner
- Native macOS development

### Acknowledgments

- Apple for Swift and SwiftUI
- macOS system APIs
- Open source community

---

## Contact & Support

For questions, issues, or contributions:

- **GitHub:** [Repository URL]
- **Email:** [Your Email]
- **Documentation:** See README.md and SETUP.md

---

**End of Documentation**

*Last Updated: February 7, 2026*  
*Version: 2.0*
