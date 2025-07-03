//
//  ShortcutRecorderView.swift
//  OnMyRadar
//
//  Created by William Parry on 24/6/2025.
//

import SwiftUI
import Carbon

class ShortcutRecorderTextField: NSTextField {
    var onActivate: (() -> Void)?
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 { // Return or Space
            onActivate?()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = ShortcutRecorderTextField()
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.placeholderString = "Click to record shortcut"
        textField.alignment = .center
        textField.focusRingType = .default
        
        updateTextField(textField)
        
        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.startRecording(_:)))
        textField.addGestureRecognizer(clickGesture)
        
        // Set up keyboard activation
        textField.onActivate = {
            context.coordinator.startRecordingFromKeyboard(textField)
        }
        
        // Store reference in coordinator
        context.coordinator.textField = textField
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        updateTextField(nsView)
    }
    
    private func updateTextField(_ textField: NSTextField) {
        if keyCode > 0 {
            var modifierString = ""
            if modifiers & UInt32(cmdKey) != 0 { modifierString += "⌘" }
            if modifiers & UInt32(shiftKey) != 0 { modifierString += "⇧" }
            if modifiers & UInt32(optionKey) != 0 { modifierString += "⌥" }
            if modifiers & UInt32(controlKey) != 0 { modifierString += "⌃" }
            
            let keyString = keyStringFromKeyCode(keyCode)
            textField.stringValue = modifierString + keyString
        } else {
            textField.stringValue = ""
        }
    }
    
    private func keyStringFromKeyCode(_ keyCode: UInt32) -> String {
        // Common key mappings
        switch keyCode {
        case 0x00: return "A"
        case 0x01: return "S"
        case 0x02: return "D"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x05: return "G"
        case 0x06: return "Z"
        case 0x07: return "X"
        case 0x08: return "C"
        case 0x09: return "V"
        case 0x0B: return "B"
        case 0x0C: return "Q"
        case 0x0D: return "W"
        case 0x0E: return "E"
        case 0x0F: return "R"
        case 0x10: return "Y"
        case 0x11: return "T"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x16: return "6"
        case 0x17: return "5"
        case 0x18: return "="
        case 0x19: return "9"
        case 0x1A: return "7"
        case 0x1B: return "-"
        case 0x1C: return "8"
        case 0x1D: return "0"
        case 0x1E: return "]"
        case 0x1F: return "O"
        case 0x20: return "U"
        case 0x21: return "["
        case 0x22: return "I"
        case 0x23: return "P"
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x27: return "'"
        case 0x28: return "K"
        case 0x29: return ";"
        case 0x2A: return "\\"
        case 0x2B: return ","
        case 0x2C: return "/"
        case 0x2D: return "N"
        case 0x2E: return "M"
        case 0x2F: return "."
        case 0x32: return "`"
        case 0x24: return "⏎"
        case 0x30: return "⇥"
        case 0x31: return "Space"
        case 0x33: return "⌫"
        case 0x35: return "⎋"
        case 0x7A: return "F1"
        case 0x78: return "F2"
        case 0x63: return "F3"
        case 0x76: return "F4"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x6D: return "F10"
        case 0x67: return "F11"
        case 0x6F: return "F12"
        default: return "?"
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: ShortcutRecorderView
        var eventMonitor: Any?
        weak var textField: NSTextField?
        
        init(_ parent: ShortcutRecorderView) {
            self.parent = parent
        }
        
        @objc func startRecording(_ sender: NSClickGestureRecognizer) {
            guard let textField = sender.view as? NSTextField else { return }
            startRecordingFromKeyboard(textField)
        }
        
        func startRecordingFromKeyboard(_ textField: NSTextField) {
            self.textField = textField
            
            textField.stringValue = "Type shortcut or ESC to clear"
            textField.textColor = .systemBlue
            
            // Start monitoring key events
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyEvent(event)
                return nil // Consume the event
            }
        }
        
        private func handleKeyEvent(_ event: NSEvent) {
            // Check for escape key to clear
            if event.keyCode == 0x35 { // Escape key
                // Clear the shortcut
                parent.keyCode = 0
                parent.modifiers = 0
                
                // Stop monitoring
                if let monitor = eventMonitor {
                    NSEvent.removeMonitor(monitor)
                    eventMonitor = nil
                }
                
                // Reset text field appearance
                textField?.textColor = .labelColor
                parent.updateTextField(textField!)
                return
            }
            
            // Get modifiers
            let modifierFlags = event.modifierFlags
            var modifiers: UInt32 = 0
            
            if modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }
            if modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
            if modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
            if modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }
            
            // Require at least one modifier
            if modifiers == 0 {
                return
            }
            
            // Get key code
            let keyCode = UInt32(event.keyCode)
            
            // Update the binding
            parent.keyCode = keyCode
            parent.modifiers = modifiers
            
            // Stop monitoring
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
            
            // Reset text field appearance
            textField?.textColor = .labelColor
            parent.updateTextField(textField!)
        }
    }
}
