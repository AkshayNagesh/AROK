# AROK Development Notes

## Conversation Summary

### Initial Requirements

User wanted a macOS menu bar extension app that:
1. Pops up next to battery icon (menu bar)
2. Shows CPU, temperature, and memory storage
3. Automated memory allocation based on user activity
4. Context-aware: understands anime watching vs coding vs school work
5. Target: YC founders and developers
6. Goal: Prevent Mac freezes during heavy workloads

### Key Decisions Made

#### 1. Temperature Monitoring → SKIPPED
**Reason:** macOS doesn't expose CPU temperature via standard APIs. Would require kernel extensions or third-party tools, adding complexity and potential failure points.

**Alternative:** Use CPU load percentage as a proxy for thermal pressure.

#### 2. Activity Detection → Process Names + Window Titles
**Reason:** Detecting "watching anime" vs "coding" is ambiguous. Simple heuristics are more reliable than complex AI.

**Implementation:**
- Process name patterns (Chrome, YouTube = media; Docker, VS Code = dev)
- Active window title detection via AppleScript
- Mode-based scoring (Build/Chill/Focus)

#### 3. Architecture → Native Swift (Not Electron)
**Reason:** Better performance, true macOS integration, lower memory footprint.

**Benefits:**
- No JavaScript bridge overhead
- Native menu bar integration
- Better user experience
- More reliable

#### 4. AI Advisor → Zero-Latency Heuristics (Not API)
**Reason:** API calls add latency (100-500ms), require network, cost money, and raise privacy concerns.

**Implementation:**
- Fast heuristic-based scoring
- Context-aware adjustments (memory, CPU, process type)
- Instant decisions (0ms latency)
- Works offline

### Technical Challenges Solved

#### Challenge 1: Process Suspension Permissions
**Problem:** Some processes can't be suspended due to permissions.

**Solution:** Virtual suspension fallback - track suspended processes internally even if SIGSTOP fails.

#### Challenge 2: Menu Bar Integration
**Problem:** Need to hide dock icon and show only in menu bar.

**Solution:** Set `LSUIElement = YES` in Info.plist and `NSApp.setActivationPolicy(.accessory)`.

#### Challenge 3: Real-Time Updates
**Problem:** Need to update UI every 2 seconds without blocking.

**Solution:** Async/await with Timer publishers, update on main thread.

#### Challenge 4: Demo Mode
**Problem:** Need reliable demo for hackathon presentation.

**Solution:** Stub SystemMonitor methods to return fixed values, toggle with CMD+Shift+D.

### Code Architecture Decisions

#### State Management: Centralized Singleton
- `AppState.shared` is single source of truth
- All views observe via `@StateObject` or `@ObservedObject`
- Async operations update state on main thread

#### Error Handling: Defensive Everywhere
- All system calls wrapped in try/catch
- Fallback to cached values on error
- Never show errors to user
- Graceful degradation

#### Process Scoring: Layered Approach
1. Base score from IntentEngine (mode-based)
2. Enhanced by AIAdvisor (heuristics)
3. Adjusted by context (memory, CPU, type)
4. Final score determines suspend priority

### What Was Built

#### Core Modules (8 files):

1. **AROKApp.swift** - App entry, menu bar setup
2. **AppState.swift** - Central state management
3. **ContentView.swift** - SwiftUI user interface
4. **SystemMonitor.swift** - RAM/CPU monitoring
5. **ProcessIntervener.swift** - Process suspend/resume
6. **IntentEngine.swift** - Mode-based scoring
7. **AIAdvisor.swift** - Enhanced heuristic scoring
8. **DemoMode.swift** - Demo simulation

#### Features Implemented:

✅ Menu bar integration  
✅ Real-time RAM/CPU monitoring  
✅ Process list with memory/CPU per process  
✅ Suspend/resume functionality  
✅ Intent-aware modes (Build/Chill/Focus)  
✅ Auto-suspend at 85% RAM threshold  
✅ Zero-latency AI scoring  
✅ Demo mode toggle  
✅ Glassmorphism UI  
✅ Keyboard shortcuts  
✅ Notifications  

### What Was NOT Built (By Design)

❌ Temperature monitoring (too complex, unreliable)  
❌ Real AI API integration (latency, cost, privacy)  
❌ Disk cleaner (stretch goal, not core)  
❌ Unit tests (time constraints)  
❌ Settings UI (MVP focus)  

### Future Enhancements (Post-Hackathon)

1. **Temperature Monitoring**
   - Integrate SMC library
   - Show thermal pressure

2. **Real AI Integration**
   - Optional OpenAI/Claude API
   - Learning from behavior

3. **Activity Detection ML**
   - Machine learning classification
   - Better context understanding

4. **Disk Cleaner**
   - Cache cleanup
   - Log removal

5. **Statistics & History**
   - Usage trends
   - Suspension history

6. **Settings UI**
   - Customizable thresholds
   - Process whitelist/blacklist

### Lessons Learned

1. **Start Simple:** Heuristics work better than complex AI for MVP
2. **Native > Electron:** Better performance and integration
3. **Defensive Coding:** Always have fallbacks
4. **Demo Mode Critical:** Essential for hackathon presentations
5. **User Control:** Always allow manual override

### Hackathon Strategy

**Winning Elements:**
1. Solves real problem (Mac freezes)
2. Technical depth (process control)
3. Polished UI (native macOS)
4. Demo-ready (demo mode)
5. Clear value prop (before OS panics)

**Demo Flow (90 seconds):**
1. Problem (0:00-0:15)
2. Solution (0:15-0:30)
3. Build Mode (0:30-0:45)
4. Auto-Suspend (0:45-1:00)
5. Manual Control (1:00-1:15)
6. Closing (1:15-1:30)

### Code Quality Notes

- **Error Handling:** Comprehensive try/catch everywhere
- **Performance:** Caching, async operations
- **UI:** Smooth animations, glassmorphism
- **Documentation:** Inline comments, this doc
- **Maintainability:** Modular, single responsibility

### Known Limitations

1. Some processes require elevated permissions
2. System processes cannot be suspended
3. Virtual suspension is tracked internally only
4. Active window detection needs Accessibility permission
5. No unit tests (yet)

### Development Timeline

**Planning:** ~30 minutes
- Requirements analysis
- Feasibility assessment
- Architecture design

**Implementation:** ~4 hours
- Core modules (2 hours)
- UI development (1 hour)
- Integration & testing (1 hour)

**Documentation:** ~1 hour
- Code comments
- README
- This document

**Total:** ~5.5 hours

### Next Steps for Developers

1. **Read:** COMPREHENSIVE_DOCUMENTATION.md
2. **Setup:** Follow SETUP.md
3. **Build:** Open in Xcode, build and run
4. **Test:** Try all features, enable demo mode
5. **Extend:** Add features from Future Development section

### Questions for Future Development

1. Should we add real AI API integration?
2. How to handle process suspension permissions better?
3. Should we add a settings/preferences window?
4. How to improve activity detection accuracy?
5. Should we support multiple modes simultaneously?

---

**End of Development Notes**

*These notes capture the thought process, decisions, and implementation details from the initial development session.*
