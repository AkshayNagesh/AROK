# Xcode Quick Start Guide

## Steps to Run AROK

### 1. Open Project
```bash
open AROK.xcodeproj
```
✅ **Done!** (Xcode should be open now)

### 2. Select Target
- Top-left dropdown should show: **AROK > My Mac**
- If it says "Any Mac", that's fine too

### 3. Build (CMD+B)
Press `CMD+B` or go to **Product → Build**

**Expected**: "Build Succeeded" message

### 4. Run (CMD+R)
Press `CMD+R` or go to **Product → Run**

**Expected**: App appears in menu bar (top-right corner)

---

## Common Build Errors & Fixes

### ❌ Error: "Signing for 'AROK' requires a development team"

**Fix:**
1. Click on `AROK` project in left sidebar (blue icon at top)
2. Select `AROK` target in the main panel
3. Go to **Signing & Capabilities** tab
4. Check **"Automatically manage signing"**
5. Select your Apple ID from **Team** dropdown
6. If no team exists, click "Add Account" and sign in with your Apple ID (free)

### ❌ Error: "Cannot find 'Logger' in scope"

**Fix:**
Add missing import at top of file:
```swift
import os.log
```

### ❌ Error: "Cannot find 'URLSession' in scope"

**Fix:**
Add missing import:
```swift
import Foundation
```

### ❌ Error: Module compilation errors in multiple files

**Fix:**
1. Clean build folder: **Product → Clean Build Folder** (CMD+Shift+K)
2. Rebuild: **Product → Build** (CMD+B)

### ❌ Error: "Minimum deployment target 14.0"

**Fix:**
Your macOS is older than 14.0. Options:
1. Update macOS (if possible)
2. Lower deployment target:
   - Click AROK project in sidebar
   - Select AROK target
   - **General** tab → **Minimum Deployments**
   - Change to your macOS version (e.g., 13.0, 12.0)
   - Rebuild

---

## Runtime Issues

### ⚠️ App builds but doesn't appear in menu bar

**Check:**
1. Look at the **very top-right** of your screen (near battery icon)
2. The icon might be hidden - check **System Settings → Control Center → Menu Bar Only**
3. Look in the **hidden menu items** (>> icon if present)

**Debug:**
```bash
# Check if app is running
ps aux | grep AROK

# Check logs for errors
log stream --predicate 'subsystem == "com.arok.app"' --level debug
```

### ⚠️ App crashes on launch

**Check logs:**
```bash
log show --predicate 'process == "AROK"' --last 5m
```

Common causes:
- File permissions for `~/Library/Application Support/AROK/`
- Missing entitlements

**Fix:**
Ensure directory exists:
```bash
mkdir -p ~/Library/Application\ Support/AROK/
```

### ⚠️ "AROK wants to access files" permission prompt

**Fix:** Click **Allow**. This is needed for:
- Reading process information
- Writing metrics/logs
- Browser tab detection

---

## Testing the App

### 1. Verify Menu Bar Icon
- Should see RAM gauge icon in top-right
- Click it → window should open

### 2. Test Demo Mode
Press **CMD+Shift+D** while app window is open
- RAM should jump to 88%
- Should see demo processes

### 3. Test Metrics
- Should see seed data: "12 freezes prevented, 47GB saved"
- If zeros, wait 5 minutes for real data

### 4. Test Browser Tabs
- Open Brave/Chrome with multiple tabs
- Click **"Refresh"** button in Browser Tabs section
- Should see categorized tabs

### 5. Test AI Predictions (Optional)
- Set API key: `export ANTHROPIC_API_KEY="sk-ant-..."`
- Relaunch app
- Click **"Analyze"** button (brain icon)
- Should see predictions after 3-5 seconds

---

## Performance Check

```bash
# Watch app memory usage
while true; do
  ps aux | grep AROK | grep -v grep | awk '{print $3"% CPU  "$4"% MEM  "$11}'
  sleep 2
done
```

**Expected:**
- CPU: 0-5% idle, 10-20% during updates
- Memory: 50-150 MB

---

## If Everything Fails

### Nuclear Options

**Option 1: Clean Everything**
```bash
cd /Users/devadharson/AROK
rm -rf ~/Library/Developer/Xcode/DerivedData/AROK-*
```
Then rebuild in Xcode.

**Option 2: Verify Xcode Installation**
```bash
xcode-select --install
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

**Option 3: Create New Project**
If project file is corrupted, create new project:
1. Xcode → File → New → Project
2. macOS → App
3. Product Name: AROK
4. Drag all `.swift` files from `Sources/` into project

---

## Quick Debugging Commands

```bash
# Is Xcode command line tools installed?
xcode-select -p

# What Xcode version?
xcodebuild -version

# Build from terminal (see full errors)
cd /Users/devadharson/AROK
xcodebuild -project AROK.xcodeproj -scheme AROK -configuration Debug

# Run from terminal
./build/Debug/AROK.app/Contents/MacOS/AROK
```

---

## Still Stuck?

1. **Screenshot the error** - helps identify the issue
2. **Copy full error text** from Xcode issue navigator
3. **Check** [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) for testing checklist

---

## Success Criteria

✅ App builds without errors
✅ App appears in menu bar
✅ Clicking icon opens window
✅ RAM gauge shows percentage
✅ Can switch modes (Build/Chill/Focus)
✅ Metrics show seed data
✅ Demo mode works (CMD+Shift+D)

**If you got this far, you're ready to demo! 🎉**
