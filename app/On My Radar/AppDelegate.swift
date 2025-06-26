//
//  AppDelegate.swift
//  OnMyRadar
//
//  Created by William Parry on 24/6/2025.
//

import Cocoa
import SwiftUI
import SwiftData
import Carbon

// Global hotkey manager
class GlobalHotkeyManager {
    private var eventHotKey: EventHotKeyRef?
    private static var eventHandler: EventHandlerRef?
    private var onHotkey: (() -> Void)?
    
    init() {
        // Event handler will be set up on first hotkey registration
    }
    
    deinit {
        unregisterHotkey()
    }
    
    private func setupEventHandler() {
        if GlobalHotkeyManager.eventHandler == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let handler: EventHandlerUPP = { _, _, userData in
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
                manager.onHotkey?()
                return noErr
            }
            
            InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &GlobalHotkeyManager.eventHandler)
        }
    }
    
    func registerHotkey(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        unregisterHotkey()
        self.onHotkey = action
        
        let hotkeyID = EventHotKeyID(signature: OSType(0x5749544F), id: 1) // "OMR" for OnMyRadar
        var eventHotKey: EventHotKeyRef?
        let userData = Unmanaged.passUnretained(self).toOpaque()
        
        RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &eventHotKey)
        self.eventHotKey = eventHotKey
        
        // Update event handler with userData
        if let handler = GlobalHotkeyManager.eventHandler {
            RemoveEventHandler(handler)
            GlobalHotkeyManager.eventHandler = nil
        }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerWithUserData: EventHandlerUPP = { _, _, userData in
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
            manager.onHotkey?()
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handlerWithUserData, 1, &eventType, userData, &GlobalHotkeyManager.eventHandler)
    }
    
    func unregisterHotkey() {
        if let eventHotKey = eventHotKey {
            UnregisterEventHotKey(eventHotKey)
            self.eventHotKey = nil
        }
        onHotkey = nil
    }
}

// Custom panel that can become key window even when borderless
class BorderlessPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class FloatingPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private let modelContainer: ModelContainer
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    weak var menuBarController: MenuBarController?
    
    private let windowFrameKey = "OnMyRadarWindowFrame"
    
    var isPanelKeyWindow: Bool {
        return panel?.isKeyWindow ?? false
    }
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        setupPanel()
        
        // Listen for reset panel position notification
        NotificationCenter.default.addObserver(self, selector: #selector(resetPanelPosition), name: NSNotification.Name("ResetPanelPosition"), object: nil)
    }
    
    private func setupPanel() {
        let contentView = NSHostingView(rootView: MenuBarView()
            .modelContainer(modelContainer))
        
        // Get saved frame or use default
        let defaultRect = NSRect(x: 0, y: 0, width: 320, height: 200)
        let savedFrame = UserDefaults.standard.string(forKey: windowFrameKey)
        let initialRect = savedFrame != nil ? NSRectFromString(savedFrame!) : defaultRect
        
        panel = BorderlessPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        
        panel?.contentView = contentView
        panel?.title = "On My Radar"
        panel?.level = .floating
        panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel?.isMovableByWindowBackground = true
        panel?.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        panel?.isOpaque = true
        panel?.hasShadow = true
        panel?.delegate = self
        panel?.hidesOnDeactivate = false
        panel?.isReleasedWhenClosed = false
        panel?.minSize = NSSize(width: 250, height: 150)
        panel?.maxSize = NSSize(width: 600, height: 800)
        
        // Position in top right if no saved position
        if savedFrame == nil {
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let panelFrame = panel?.frame ?? .zero
                let x = screenFrame.maxX - panelFrame.width - 20
                let y = screenFrame.maxY - panelFrame.height - 40
                panel?.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        
        // Set frame autosave name
        panel?.setFrameAutosaveName("OnMyRadarPanel")
        
        // Listen for settings window request
        NotificationCenter.default.addObserver(self, selector: #selector(showSettings), name: NSNotification.Name("ShowSettingsWindow"), object: nil)
        
        // Listen for clear all tasks request
        NotificationCenter.default.addObserver(self, selector: #selector(clearAllTasks), name: NSNotification.Name("ClearAllTasks"), object: nil)
    }
    
    func toggle() {
        if panel?.isVisible == true {
            panel?.close()
            NotificationCenter.default.post(name: NSNotification.Name("PanelDidBecomeInactive"), object: nil)
        } else {
            panel?.makeKeyAndOrderFront(nil)
            panel?.orderFrontRegardless()
            // Activate the app to receive keyboard input
            NSApp.activate(ignoringOtherApps: true)
            // Set initial opacity
            panel?.alphaValue = 1.0
            NotificationCenter.default.post(name: NSNotification.Name("PanelDidBecomeActive"), object: nil)
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        // Save window frame when closing
        if let frame = panel?.frame {
            UserDefaults.standard.set(NSStringFromRect(frame), forKey: windowFrameKey)
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        // Save window frame when resizing
        if let frame = panel?.frame {
            UserDefaults.standard.set(NSStringFromRect(frame), forKey: windowFrameKey)
        }
    }
    
    func windowDidMove(_ notification: Notification) {
        // Save window frame when moving
        if let frame = panel?.frame {
            UserDefaults.standard.set(NSStringFromRect(frame), forKey: windowFrameKey)
        }
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Set full opacity when window becomes active
        panel?.animator().alphaValue = 1.0
        NotificationCenter.default.post(name: NSNotification.Name("PanelDidBecomeActive"), object: nil)
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Set custom opacity when window becomes inactive
        let context = modelContainer.mainContext
        let request = FetchDescriptor<Settings>()
        
        do {
            let settings = try context.fetch(request).first
            let opacity = settings?.inactivePanelOpacity ?? 0.9
            panel?.animator().alphaValue = opacity
        } catch {
            panel?.animator().alphaValue = 0.9
        }
        NotificationCenter.default.post(name: NSNotification.Name("PanelDidBecomeInactive"), object: nil)
    }
    
    @objc func showSettings() {
        if settingsWindow == nil || settingsWindow?.isVisible == false {
            let settingsView = SettingsView(onSave: { [weak self] in
                self?.settingsWindow?.close()
            })
            .modelContainer(modelContainer)
            
            let hostingView = NSHostingView(rootView: settingsView)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow?.title = "On My Radar Settings"
            settingsWindow?.contentView = hostingView
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func resetPanelPosition() {
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = panel?.frame ?? NSRect(x: 0, y: 0, width: 320, height: 200)
            let x = screenFrame.maxX - panelFrame.width - 20
            let y = screenFrame.maxY - panelFrame.height - 40
            panel?.setFrameOrigin(NSPoint(x: x, y: y))
            
            // Save the new position
            if let frame = panel?.frame {
                UserDefaults.standard.set(NSStringFromRect(frame), forKey: windowFrameKey)
            }
        }
    }
    
    func showAbout() {
        if aboutWindow == nil || aboutWindow?.isVisible == false {
            let aboutView = AboutView()
            let hostingView = NSHostingView(rootView: aboutView)
            
            aboutWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            aboutWindow?.title = "About On My Radar"
            aboutWindow?.contentView = hostingView
            aboutWindow?.center()
            aboutWindow?.isReleasedWhenClosed = false
        }
        
        aboutWindow?.makeKeyAndOrderFront(nil)
        aboutWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func clearAllTasks() {
        let alert = NSAlert()
        alert.messageText = "Clear All Tasks?"
        alert.informativeText = "This will permanently delete all tasks. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Clear all tasks
            Task { @MainActor in
                let context = modelContainer.mainContext
                let request = FetchDescriptor<Item>()
                
                do {
                    let items = try context.fetch(request)
                    for item in items {
                        context.delete(item)
                    }
                    try context.save()
                } catch {
                    print("Error clearing tasks: \(error)")
                }
            }
        }
    }
}

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var floatingPanel: FloatingPanelController?
    private let modelContainer: ModelContainer
    private let hotkeyManager = GlobalHotkeyManager()
    private var activeIcon: NSImage?
    private var inactiveIcon: NSImage?
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        setupMenuBar()
        setupGlobalHotkey()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Create both active and inactive icons
        activeIcon = createRadarIcon(alpha: 1.0)
        inactiveIcon = createRadarIcon(alpha: 0.7)
        
        if let button = statusItem?.button {
            // Start with inactive icon
            button.image = inactiveIcon ?? NSImage(systemSymbolName: "target", accessibilityDescription: "OnMyRadar")
            button.action = #selector(togglePanel)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Listen for panel state changes
        NotificationCenter.default.addObserver(self, selector: #selector(panelDidBecomeActive), name: NSNotification.Name("PanelDidBecomeActive"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(panelDidBecomeInactive), name: NSNotification.Name("PanelDidBecomeInactive"), object: nil)
        
        // Auto-open panel on app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.togglePanel(self?.statusItem?.button ?? NSStatusBarButton())
        }
    }
    
    private func createRadarIcon(alpha: CGFloat = 1.0) -> NSImage? {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        
        // Draw radar circles
        let center = NSPoint(x: 9, y: 9)
        let context = NSGraphicsContext.current?.cgContext
        
        // Set color for menu bar (adapts to dark/light mode)
        if let context = context {
            context.setStrokeColor(NSColor.labelColor.withAlphaComponent(alpha).cgColor)
            
            // Draw concentric circles
            for i in 1...3 {
                let radius = CGFloat(i) * 2.5
                context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, 
                                                width: radius * 2, height: radius * 2))
            }
            
            // Draw radar line at 0 degrees (pointing right)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: center.x, y: center.y))
            context.addLine(to: CGPoint(x: center.x + 7, y: center.y))
            context.strokePath()
            
            // Draw sweep gradient effect (trailing behind the line)
            // Use lower alpha for the gradient
            context.setFillColor(NSColor.labelColor.withAlphaComponent(0.15).cgColor)
            context.move(to: CGPoint(x: center.x, y: center.y))
            context.addLine(to: CGPoint(x: center.x + 7, y: center.y))
            context.addLine(to: CGPoint(x: center.x + 5, y: center.y + 5))
            context.closePath()
            context.fillPath()
        }
        
        image.unlockFocus()
        image.isTemplate = true // Makes it adapt to menu bar appearance
        return image
    }
    
    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            if floatingPanel == nil {
                floatingPanel = FloatingPanelController(modelContainer: modelContainer)
                floatingPanel?.menuBarController = self
            }
            floatingPanel?.toggle()
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let clearAllItem = NSMenuItem(title: "Clear All Tasks", action: #selector(clearAllTasks), keyEquivalent: "")
        clearAllItem.target = self
        menu.addItem(clearAllItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "About On My Radar", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc private func showSettings() {
        if floatingPanel == nil {
            floatingPanel = FloatingPanelController(modelContainer: modelContainer)
        }
        floatingPanel?.showSettings()
    }
    
    @objc private func clearAllTasks() {
        let alert = NSAlert()
        alert.messageText = "Clear All Tasks?"
        alert.informativeText = "This will permanently delete all tasks. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Clear all tasks
            Task { @MainActor in
                let context = modelContainer.mainContext
                let request = FetchDescriptor<Item>()
                
                do {
                    let items = try context.fetch(request)
                    for item in items {
                        context.delete(item)
                    }
                    try context.save()
                } catch {
                    NSAlert.showError("Failed to clear tasks: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func showAbout() {
        if floatingPanel == nil {
            floatingPanel = FloatingPanelController(modelContainer: modelContainer)
        }
        floatingPanel?.showAbout()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func panelDidBecomeActive() {
        updateStatusItemImage(active: true)
    }
    
    @objc private func panelDidBecomeInactive() {
        updateStatusItemImage(active: false)
    }
    
    
    private func updateStatusItemImage(active: Bool) {
        guard let button = statusItem?.button else { return }
        
        let baseIcon = active ? activeIcon : inactiveIcon
        button.image = baseIcon
    }
    
    
    private func setupGlobalHotkey() {
        // Default: Cmd+Shift+T
        let defaultKeyCode: UInt32 = 0x11 // T key
        let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)
        
        // Load saved hotkey from UserDefaults
        let keyCode = UInt32(UserDefaults.standard.integer(forKey: "globalHotkeyKeyCode"))
        let modifiers = UInt32(UserDefaults.standard.integer(forKey: "globalHotkeyModifiers"))
        
        let actualKeyCode = keyCode > 0 ? keyCode : defaultKeyCode
        let actualModifiers = modifiers > 0 ? modifiers : defaultModifiers
        
        hotkeyManager.registerHotkey(keyCode: actualKeyCode, modifiers: actualModifiers) { [weak self] in
            self?.togglePanel(self?.statusItem?.button ?? NSStatusBarButton())
        }
    }
    
    func updateGlobalHotkey(keyCode: UInt32, modifiers: UInt32) {
        UserDefaults.standard.set(Int(keyCode), forKey: "globalHotkeyKeyCode")
        UserDefaults.standard.set(Int(modifiers), forKey: "globalHotkeyModifiers")
        
        hotkeyManager.registerHotkey(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            self?.togglePanel(self?.statusItem?.button ?? NSStatusBarButton())
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var modelContainer: ModelContainer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create model container
        let schema = Schema([
            Item.self,
            Settings.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Initialize menu bar controller
            if let container = modelContainer {
                menuBarController = MenuBarController(modelContainer: container)
            }
            
            // Listen for hotkey updates
            NotificationCenter.default.addObserver(self, selector: #selector(updateGlobalHotkey(_:)), name: NSNotification.Name("UpdateGlobalHotkey"), object: nil)
        } catch {
            NSAlert.showError("Could not initialize data store: \(error.localizedDescription)")
            NSApp.terminate(nil)
        }
    }
    
    @objc private func updateGlobalHotkey(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let keyCode = userInfo["keyCode"] as? UInt32,
           let modifiers = userInfo["modifiers"] as? UInt32 {
            menuBarController?.updateGlobalHotkey(keyCode: keyCode, modifiers: modifiers)
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
}

extension NSAlert {
    static func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
