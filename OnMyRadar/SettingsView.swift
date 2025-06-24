//
//  SettingsView.swift
//  OnMyRadar
//
//  Created by William Parry on 24/6/2025.
//

import SwiftUI
import SwiftData
import ServiceManagement
import Carbon

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [Settings]
    
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var globalHotkeyKeyCode: UInt32 = 0
    @State private var globalHotkeyModifiers: UInt32 = 0
    
    // Local state for editing
    @State private var useSymbols = false
    @State private var todoSymbol = "+"
    @State private var todoLabel = "on me"
    @State private var waitingSymbol = "."
    @State private var waitingLabel = "waiting"
    @State private var doneSymbol = "/"
    @State private var doneLabel = "done"
    
    
    var onSave: (() -> Void)?
    
    private var settings: Settings? {
        settingsArray.first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            Form {
                // General Settings Section
                Section {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    if SMAppService.mainApp.status == .enabled {
                                        try? SMAppService.mainApp.unregister()
                                    }
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                print("Failed to update login item: \(error)")
                            }
                        }
                    
                    Toggle("Use symbols instead of text labels", isOn: $useSymbols)
                    
                    HStack {
                        Text("Global shortcut:")
                        Spacer()
                        ShortcutRecorderView(keyCode: $globalHotkeyKeyCode, modifiers: $globalHotkeyModifiers)
                            .frame(width: 150, height: 22)
                    }
                } header: {
                    Text("General")
                }
                
                // Status Customization Section
                Section {
                    VStack(spacing: 12) {
                        StatusRow(
                            title: "To Do:",
                            symbol: $todoSymbol,
                            label: $todoLabel
                        )
                        
                        StatusRow(
                            title: "Waiting:",
                            symbol: $waitingSymbol,
                            label: $waitingLabel
                        )
                        
                        StatusRow(
                            title: "Done:",
                            symbol: $doneSymbol,
                            label: $doneLabel
                        )
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Status Customization")
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            
            // Buttons outside of form sections
            HStack {
                Button("Reset to Defaults") {
                    todoSymbol = "+"
                    todoLabel = "on me"
                    waitingSymbol = "."
                    waitingLabel = "waiting"
                    doneSymbol = "/"
                    doneLabel = "done"
                    useSymbols = false
                }
                
                Spacer()
                
                Button("Save") {
                    saveSettings()
                }
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 400, height: 400)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loadSettings()
            loadHotkeySettings()
        }
    }
    
    private func loadSettings() {
        if let settings = settings {
            useSymbols = settings.useSymbols
            todoSymbol = settings.todoSymbol
            todoLabel = settings.todoLabel
            waitingSymbol = settings.waitingSymbol
            waitingLabel = settings.waitingLabel
            doneSymbol = settings.doneSymbol
            doneLabel = settings.doneLabel
        }
    }
    
    private func saveSettings() {
        let settingsToSave: Settings
        if let existingSettings = settings {
            settingsToSave = existingSettings
        } else {
            settingsToSave = Settings()
            modelContext.insert(settingsToSave)
        }
        
        settingsToSave.useSymbols = useSymbols
        settingsToSave.todoSymbol = todoSymbol
        settingsToSave.todoLabel = todoLabel
        settingsToSave.waitingSymbol = waitingSymbol
        settingsToSave.waitingLabel = waitingLabel
        settingsToSave.doneSymbol = doneSymbol
        settingsToSave.doneLabel = doneLabel
        
        do {
            try modelContext.save()
            saveHotkeySettings()
            onSave?()
        } catch {
            print("Error saving settings: \(error)")
        }
    }
    
    private func loadHotkeySettings() {
        let keyCode = UserDefaults.standard.integer(forKey: "globalHotkeyKeyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "globalHotkeyModifiers")
        
        if keyCode > 0 {
            globalHotkeyKeyCode = UInt32(keyCode)
            globalHotkeyModifiers = UInt32(modifiers)
        } else {
            // Default: Cmd+Shift+T
            globalHotkeyKeyCode = 0x11 // T key
            globalHotkeyModifiers = UInt32(cmdKey | shiftKey)
        }
    }
    
    private func saveHotkeySettings() {
        UserDefaults.standard.set(Int(globalHotkeyKeyCode), forKey: "globalHotkeyKeyCode")
        UserDefaults.standard.set(Int(globalHotkeyModifiers), forKey: "globalHotkeyModifiers")
        
        // Notify the app delegate to update the hotkey
        NotificationCenter.default.post(name: NSNotification.Name("UpdateGlobalHotkey"), object: nil, userInfo: [
            "keyCode": globalHotkeyKeyCode,
            "modifiers": globalHotkeyModifiers
        ])
    }
}

struct StatusRow: View {
    let title: String
    @Binding var symbol: String
    @Binding var label: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .frame(width: 60, alignment: .trailing)
            
            HStack(spacing: 8) {
                Text("Symbol:")
                    .foregroundColor(.secondary)
                    .frame(width: 55, alignment: .trailing)
                
                TextField("", text: $symbol)
                    .frame(width: 40)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .onChange(of: symbol) { _, newValue in
                        if newValue.count > 1 {
                            symbol = String(newValue.prefix(1))
                        }
                    }
            }
            
            HStack(spacing: 8) {
                Text("Label:")
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
                
                TextField("", text: $label)
                    .frame(width: 100)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .onChange(of: label) { _, newValue in
                        if newValue.count > 7 {
                            label = String(newValue.prefix(7))
                        }
                    }
            }
            
            Spacer()
        }
    }
}
