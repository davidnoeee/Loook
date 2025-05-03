import SwiftUI

@main
struct EyeHealthApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    var reminderManager = ReminderManager()
    var overlayWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Eye Health")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        setupMenu()
        setupPopover()
        setupOverlayWindow()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(togglePopover), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.button?.sendAction(on: [.rightMouseUp, .leftMouseUp])
    }
    
    func setupPopover() {
        // Configure the settings popover
        popover.behavior = .transient
        popover.animates = true
        
        // Create a hosting view for our SwiftUI settings view
        let settingsView = SettingsView(reminderManager: reminderManager, isPresented: Binding<Bool>(
            get: { return self.popover.isShown },
            set: { if !$0 { self.popover.performClose(nil) } }
        ))
        
        let hostingController = NSHostingController(rootView: settingsView)
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 350, height: 10) // Height will adjust based on content
    }
    
    func setupOverlayWindow() {
        // Create a transparent overlay window for reminders
        overlayWindow = NSWindow(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        overlayWindow?.backgroundColor = .clear
        overlayWindow?.isOpaque = false
        overlayWindow?.hasShadow = false
        overlayWindow?.level = .floating
        overlayWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayWindow?.ignoresMouseEvents = true
        
        // Set the content view as our main ContentView
        let contentView = NSHostingView(rootView: ContentView())
        overlayWindow?.contentView = contentView
        
        // Show the transparent overlay window
        overlayWindow?.orderFrontRegardless()
    }
    
    @objc func togglePopover(sender: AnyObject) {
        // Handle right-click and left-click differently
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
                return
            }
        }
        
        // Left click shows the settings popover
        if let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    @objc func openSettings() {
        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
