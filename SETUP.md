# AROK Setup Guide

## Quick Start (Xcode)

1. **Open Xcode** and create a new project:
   - File → New → Project
   - Choose "macOS" → "App"
   - Product Name: `AROK`
   - Interface: SwiftUI
   - Language: Swift
   - Uncheck "Include Tests" (optional)

2. **Replace the default files** with the files from `Sources/`:
   - Delete the default `ContentView.swift` and `AROKApp.swift`
   - Copy all files from `Sources/` into your project

3. **Add to Info.plist** (or use the provided one):
   - Set `LSUIElement` to `YES` (to hide dock icon)
   - Or add to your project's Info.plist:
     ```xml
     <key>LSUIElement</key>
     <true/>
     ```

4. **Build and Run** (CMD+R)

## Alternative: Use Provided Xcode Project

If the provided `AROK.xcodeproj` doesn't work:

1. Open `AROK.xcodeproj` in Xcode
2. If files are missing, add them manually:
   - Right-click on project → Add Files to "AROK"
   - Select all files from `Sources/`
   - Make sure "Copy items if needed" is checked
   - Add to target: AROK

3. Build (CMD+B) and Run (CMD+R)

## Permissions

The app may need:
- **Accessibility**: For detecting active windows (System Preferences → Security & Privacy → Privacy → Accessibility)
- **Full Disk Access**: Optional, for better process detection (System Preferences → Security & Privacy → Privacy → Full Disk Access)

## Troubleshooting

### Build Errors

If you get "Cannot find type" errors:
- Make sure all files in `Sources/` are added to the target
- Clean build folder: Product → Clean Build Folder (Shift+CMD+K)
- Rebuild

### Menu Bar Icon Not Showing

- Check that `LSUIElement` is set to `YES` in Info.plist
- The app runs as a menu bar app (no dock icon)

### Process Suspension Not Working

- Some processes require elevated permissions
- The app uses virtual suspension as fallback (tracked internally)
- System processes cannot be suspended

## Demo Mode

Press `CMD+Shift+D` (or `CMD+Shift+N` as fallback) to toggle demo mode.

## Testing

1. Run the app
2. Click the CPU icon in menu bar
3. Switch between Build/Chill/Focus modes
4. Watch RAM usage update in real-time
5. Try suspending a process manually
6. Enable demo mode to see simulated high memory pressure
