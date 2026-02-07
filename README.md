# AROK - Memory Governor for macOS

AROK is an intent-aware compute governor that keeps your Mac responsive by pausing low-priority apps before memory pressure causes system freezes.

## Features

- **Menu Bar Integration**: Native macOS menu bar app that shows CPU and memory usage
- **Intent-Aware Modes**: Build, Chill, and Focus modes that optimize memory allocation based on your activity
- **Auto-Suspend**: Automatically pauses low-priority processes when memory pressure exceeds 85%
- **Process Control**: Manual suspend/resume for any process
- **Demo Mode**: Toggle with CMD+Shift+D (or CMD+Shift+N) for hackathon demos
- **Zero-Latency AI**: Fast heuristic-based process scoring (no API calls needed)

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

```
Sources/
├── AROKApp.swift          # App entry point, menu bar setup
├── AppState.swift         # Central state management
├── ContentView.swift      # SwiftUI main UI
├── SystemMonitor.swift    # RAM/CPU monitoring via vm_stat and ps
├── ProcessIntervener.swift # SIGSTOP/SIGCONT process control
├── IntentEngine.swift     # Mode-based process scoring
├── AIAdvisor.swift        # Enhanced heuristic-based scoring
└── DemoMode.swift         # Demo mode simulation
```

## Technical Details

- **Memory Monitoring**: Uses `vm_stat` to get accurate RAM usage
- **CPU Monitoring**: Uses `top` command for CPU percentage
- **Process Control**: Uses `kill -STOP` and `kill -CONT` signals
- **Virtual Fallback**: If SIGSTOP fails (permissions), tracks suspension virtually
- **Activity Detection**: Uses active window titles and process names

## Hackathon Demo Flow (90 seconds)

1. **Problem** (0:00-0:15): Show Mac freezing during builds
2. **Solution** (0:15-0:30): AROK menu bar icon (green → yellow → red)
3. **Toggle Build Mode** (0:30-0:45): RAM spikes to 88%
4. **Auto-Suspend** (0:45-1:00): Chrome, Spotify pause → RAM drops to 65%
5. **Resume Docker** (1:00-1:15): Smooth, no freeze
6. **Close** (1:15-1:30): "AROK acts before the OS panics—so you never smash a laptop again."

## License

Copyright © 2026 AROK. All rights reserved.
