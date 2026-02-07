import SwiftUI
import AppKit
import UserNotifications

@main
struct AROKApp: App {
    @StateObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            // Permission granted or denied, continue anyway
        }
        
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "AROK")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
        
        // Close popover when clicking outside
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
        
        // Setup keyboard shortcut for demo mode (CMD+Shift+D, fallback to CMD+Shift+N)
        setupKeyboardShortcuts()
        
        // Start monitoring
        SystemMonitor.shared.startMonitoring()
        
        // Update status bar icon color based on RAM
        updateStatusBarIcon()
    }
    
    func setupKeyboardShortcuts() {
        // Setup global hotkey monitor for demo mode toggle
        // CMD+Shift+D (fallback to CMD+Shift+N)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection([.command, .shift])
            if modifiers == [.command, .shift] {
                if event.keyCode == 2 { // D key
                    Task { @MainActor in
                        AppState.shared.toggleDemoMode()
                    }
                } else if event.keyCode == 45 { // N key (fallback)
                    Task { @MainActor in
                        AppState.shared.toggleDemoMode()
                    }
                }
            }
        }
        
        // Also handle local events (when app is focused)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection([.command, .shift])
            if modifiers == [.command, .shift] {
                if event.keyCode == 2 || event.keyCode == 45 {
                    Task { @MainActor in
                        AppState.shared.toggleDemoMode()
                    }
                    return nil // Consume the event
                }
            }
            return event
        }
    }
    
    @objc func togglePopover() {
        if let button = statusBarItem?.button {
            if let popover = popover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }
    
    func updateStatusBarIcon() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                let ramUsage = await SystemMonitor.shared.getRAMUsage()
                if let button = self?.statusBarItem?.button {
                    let color: NSColor
                    if ramUsage.percentage <= 70 {
                        color = .systemGreen
                    } else if ramUsage.percentage <= 85 {
                        color = .systemYellow
                    } else {
                        color = .systemRed
                    }
                    
                    let image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "AROK")
                    image?.isTemplate = true
                    button.image = image
                    button.contentTintColor = color
                }
            }
        }
    }
}
