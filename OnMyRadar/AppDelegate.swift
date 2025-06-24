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
        setupEventHandler()
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
    
    private let windowFrameKey = "OnMyRadarWindowFrame"
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        setupPanel()
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
        panel?.backgroundColor = .windowBackgroundColor
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
    }
    
    func toggle() {
        if panel?.isVisible == true {
            panel?.close()
        } else {
            panel?.makeKeyAndOrderFront(nil)
            panel?.orderFrontRegardless()
            // Activate the app to receive keyboard input
            NSApp.activate(ignoringOtherApps: true)
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
    
    func showSettings() {
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
    }
}

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var floatingPanel: FloatingPanelController?
    private let modelContainer: ModelContainer
    private let hotkeyManager = GlobalHotkeyManager()
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        setupMenuBar()
        setupGlobalHotkey()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "OnMyRadar")
            button.action = #selector(togglePanel)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            if floatingPanel == nil {
                floatingPanel = FloatingPanelController(modelContainer: modelContainer)
            }
            floatingPanel?.toggle()
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
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
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
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
