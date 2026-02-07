# AROK - Memory Governor for macOS

AROK is an intent-aware compute governor that keeps your Mac responsive by pausing low-priority apps before memory pressure causes system freezes.

## 📚 Documentation

### Core Documentation
- **[COMPREHENSIVE_DOCUMENTATION.md](./COMPREHENSIVE_DOCUMENTATION.md)** - Complete technical documentation (architecture, API reference, code breakdown)
- **[DEVELOPMENT_NOTES.md](./DEVELOPMENT_NOTES.md)** - Development journey, decisions, and lessons learned
- **[SETUP.md](./SETUP.md)** - Detailed setup and installation instructions
- **[DEMO_SCRIPT.md](./DEMO_SCRIPT.md)** - 90-second demo presentation script
- **[PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md)** - Quick project overview and highlights

### Phase 2 Documentation
- **[IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md)** - Handoff guide: what's implemented, what needs testing
- **[METRICS_SYSTEM.md](./METRICS_SYSTEM.md)** - Complete metrics tracking system guide
- **[BROWSER_INTEGRATION.md](./BROWSER_INTEGRATION.md)** - Browser tab detection and management
- **[API_INTEGRATION.md](./API_INTEGRATION.md)** - Claude AI setup, usage, and troubleshooting

## Features

### Core Features
- **Menu Bar Integration**: Native macOS menu bar app that shows CPU and memory usage
- **Intent-Aware Modes**: Build, Chill, and Focus modes that optimize memory allocation based on your activity
- **Auto-Suspend**: Automatically pauses low-priority processes when memory pressure exceeds 85%
- **Process Control**: Manual suspend/resume for any process
- **Demo Mode**: Toggle with CMD+Shift+D (or CMD+Shift+N) for hackathon demos
- **Zero-Latency AI**: Fast heuristic-based process scoring (no API calls needed)

### Phase 2 Features ✨

#### 📊 Impact Metrics Dashboard
Track your productivity gains in real-time:
- **Freezes Prevented**: Count of system freezes avoided
- **RAM Saved**: Total gigabytes reclaimed from suspended processes
- **Time Saved**: Estimated productivity hours recovered (5 min per freeze)
- **Processes Managed**: Total number of processes suspended/resumed
- **Persistent Metrics**: All data saved across app restarts

#### 🌐 Multi-Browser Tab Management
Intelligent browser tab detection and categorization:
- **Supported Browsers**: Chrome, Brave, Edge, Opera, Vivaldi
- **Auto-Detection**: Scans all running Chromium browsers
- **Smart Categorization**: Media 🎥, Development 💻, Social 💬, Documents 📄, Other 🌐
- **One-Click Suspension**: Suspend all media tabs instantly
- **RAM Estimation**: Shows estimated memory usage per category

#### 🤖 AI-Powered Predictive Prevention
Claude AI analyzes your patterns to prevent freezes before they happen:
- **Pattern Recognition**: Identifies recurring memory spikes
- **Proactive Actions**: Suspends processes 5 minutes before predicted freezes
- **Activity Logging**: Tracks system state every 5 minutes for analysis
- **Confidence Scoring**: Shows prediction confidence (0-100%)
- **Persistent Predictions**: Saved across app sessions

#### 💬 Personality & Engagement
Snarky, helpful notifications that make memory management fun:
- **5 Notification Types**: Auto-suspend, manual suspend, resume, predictive, tab suspension
- **Randomized Messages**: Different snarky message each time
- **Clean & Professional**: Shareable in team settings
- **Context-Aware**: Tailored to the action taken

## Building

### Requirements
- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### Build Steps

1. Open the project in Xcode:
```bash
open AROK.xcodeproj
```

2. Select the AROK target and build (CMD+B)

3. Run the app (CMD+R)

The app will appear in your menu bar next to the battery icon.

### Claude API Setup (Optional)

For AI-powered predictive prevention, configure your Anthropic API key:

**Option 1: Environment Variable (Recommended)**
```bash
export ANTHROPIC_API_KEY="sk-ant-api03-YOUR-KEY-HERE"
open -a AROK.app
```

**Option 2: Hardcode (Hackathon only)**
Edit `Sources/PredictiveEngine.swift` line 57:
```swift
private let apiKey = "sk-ant-api03-YOUR-KEY-HERE"
```

Get your API key from: [console.anthropic.com](https://console.anthropic.com)

See [API_INTEGRATION.md](./API_INTEGRATION.md) for complete setup guide.

## Usage

### Modes

- **Build Mode**: Optimizes for development work. Suspends media apps (Chrome, Spotify, etc.) to free memory for dev tools.
- **Chill Mode**: Optimizes for media consumption. Suspends dev tools to free memory for media apps.
- **Focus Mode**: Suspends distracting media apps while keeping dev tools running.

### Demo Mode

Press `CMD+Shift+D` (or `CMD+Shift+N` as fallback) to toggle demo mode. This simulates high memory pressure (88%) and shows demo processes for presentation purposes.

### Auto-Suspend

When memory usage exceeds 85%, AROK automatically suspends the 3 lowest-priority processes based on your current mode. You'll receive a notification when this happens.

## Architecture

### Core Components
```
Sources/
├── AROKApp.swift           # App entry point, menu bar setup
├── AppState.swift          # Central state management
├── ContentView.swift       # SwiftUI main UI
├── SystemMonitor.swift     # RAM/CPU monitoring via vm_stat and ps
├── ProcessIntervener.swift # SIGSTOP/SIGCONT process control
├── IntentEngine.swift      # Mode-based process scoring
├── AIAdvisor.swift         # Enhanced heuristic-based scoring
└── DemoMode.swift          # Demo mode simulation
```

### Phase 2 Components
```
Sources/
├── MetricsManager.swift    # Impact tracking & persistence
├── NotificationManager.swift # Snarky notification system
├── BrowserManager.swift    # Multi-browser tab detection
├── ActivityLogger.swift    # Usage pattern logging
└── PredictiveEngine.swift  # Claude AI integration
```

### Documentation
```
├── COMPREHENSIVE_DOCUMENTATION.md  # Complete technical docs
├── IMPLEMENTATION_STATUS.md        # Handoff guide for testing
├── METRICS_SYSTEM.md              # Metrics system guide
├── BROWSER_INTEGRATION.md         # Browser tab detection guide
├── API_INTEGRATION.md             # Claude API setup & usage
├── DEVELOPMENT_NOTES.md           # Development journey
├── SETUP.md                       # Setup instructions
└── DEMO_SCRIPT.md                 # 90-second demo script
```

## Technical Details

### Core Systems
- **Memory Monitoring**: Uses `vm_stat` to get accurate RAM usage
- **CPU Monitoring**: Uses `top` command for CPU percentage
- **Process Control**: Uses `kill -STOP` and `kill -CONT` signals
- **Virtual Fallback**: If SIGSTOP fails (permissions), tracks suspension virtually
- **Activity Detection**: Uses active window titles and process names

### Phase 2 Systems
- **Metrics Persistence**: JSON storage in `~/Library/Application Support/AROK/metrics.json`
- **Browser Detection**: AppleScript queries to Chromium browsers
- **Tab Categorization**: URL pattern matching (50+ patterns across 5 categories)
- **Activity Logging**: Line-delimited JSON, 5-minute intervals, 3-day seed data
- **AI Analysis**: Claude Sonnet 4.5 via REST API, structured JSON responses
- **Pattern Matching**: Time-based triggers with 60-second checking interval
- **Notification System**: Random selection from curated message banks

## Hackathon Demo Flow (90 seconds)

1. **Problem** (0:00-0:15): "Mac freezes during builds with Docker + Chrome open. Lose work, context, productivity."
2. **Solution** (0:15-0:30): "AROK prevents freezes BEFORE they happen using intent-aware memory management."
3. **Metrics** (0:30-0:45): "Look - 12 freezes prevented this week, 47GB saved, over 2 hours of productivity recovered."
4. **Browser Tabs** (0:45-1:00): "Chrome is the biggest culprit - 50 tabs using 3GB. One click suspends all media tabs."
5. **AI Prediction** (1:00-1:15): "Claude analyzed my patterns - predicts freeze at 2pm weekdays. Proactively suspends apps 5 minutes early."
6. **Close** (1:15-1:30): "Native Swift, zero-latency, AI-powered. Never rage-quit your Mac again."

**Key Differentiators**:
- Real metrics prove value (not just claims)
- Browser tabs = relatable #1 memory hog
- AI prediction = technical depth + differentiation
- Snarky personality = memorable
- Native Swift = professional polish

## License

Copyright © 2026 AROK. All rights reserved.
