# AROK Demo Script (90 seconds)

## Pre-Demo Setup

1. **Open Terminal** and run some memory-intensive processes:
   ```bash
   # Open Chrome with multiple tabs
   # Open Docker Desktop
   # Open Xcode or VS Code
   ```

2. **Launch AROK** from menu bar

3. **Set up demo mode** (CMD+Shift+D)

---

## Demo Flow

### 0:00-0:15 - Problem Statement
**"Mac freezes during builds. We've all been there - Docker, Chrome, VS Code, and suddenly your Mac becomes unresponsive."**

- Show frozen Mac screen (or mention the problem)
- Point to menu bar: "Current solutions just show you the problem"

### 0:15-0:30 - Solution Introduction
**"AROK is different. It's an intent-aware memory governor that prevents freezes before they happen."**

- Click AROK menu bar icon
- Show the popover with RAM gauge
- Point out: "Green means safe, yellow means warning, red means action needed"

### 0:30-0:45 - Mode Selection
**"AROK understands what you're doing. Build mode optimizes for development work."**

- Click "Build" mode
- Show RAM gauge animating up (if demo mode is on, it'll show 88%)
- Explain: "In Build mode, media apps get lower priority"

### 0:45-1:00 - Auto-Suspend Magic
**"When memory pressure hits 85%, AROK automatically suspends low-priority processes."**

- Show notification: "Memory Pressure Detected - Suspended 3 processes"
- Point to process list: "Chrome, Spotify paused automatically"
- Show RAM gauge dropping from 88% to 65%
- **Key point**: "This happens BEFORE the OS panics"

### 1:00-1:15 - Manual Control
**"You're always in control. Resume Docker when you need it."**

- Click resume on Docker process
- Show RAM ticking up slightly
- Show UI remains smooth: "No freeze, no lag"

### 1:15-1:30 - Closing Statement
**"AROK acts before the OS panics—so you never smash a laptop again. Built for YC founders and developers who need their Macs to just work."**

- Show menu bar icon (should be green/yellow now)
- Close popover
- **Final line**: "AROK: Your Mac's memory governor"

---

## Key Talking Points

1. **Intent-Aware**: Not just monitoring, but understanding what you're doing
2. **Proactive**: Acts before freezes happen (85% threshold)
3. **Zero-Latency AI**: Fast heuristic-based scoring (no API calls)
4. **Developer-Focused**: Built for people doing real work
5. **Demo Mode**: Perfect for presentations (CMD+Shift+D)

## Tips for Smooth Demo

- **Practice the timing** - 90 seconds goes fast
- **Have demo mode ready** - Toggle it before starting
- **Know your processes** - Be ready to explain what's being suspended
- **Emphasize the "before"** - AROK prevents problems, doesn't just show them
- **Show the menu bar** - It's always visible, always monitoring

## Backup Plan

If something goes wrong:
- "AROK uses virtual suspension as a fallback - even if system permissions are limited, it tracks and manages processes internally"
- "The zero-latency AI uses fast heuristics - no network calls, instant decisions"
- "Demo mode shows exactly how AROK responds to memory pressure"
