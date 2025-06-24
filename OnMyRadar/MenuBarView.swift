//
//  MenuBarView.swift
//  OnMyRadar
//
//  Created by William Parry on 24/6/2025.
//

import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @Query private var settingsArray: [Settings]
    @State private var newItemText = ""
    @FocusState private var isInputFocused: Bool
    
    private var settings: Settings? {
        settingsArray.first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag area at top
            Color.clear
                .frame(height: 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.001))
            
            // Task List
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(items) { item in
                        TaskRow(item: item, settings: settings)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .onTapGesture {
                // Unfocus text field when clicking outside
                isInputFocused = false
            }
            
            Divider()
                .opacity(0.5)
            
            // New Task Input
            HStack {
                TextField("New task", text: $newItemText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isInputFocused)
                    .onSubmit {
                        addItem()
                    }
                    .disabled(false)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .background(Color(NSColor.windowBackgroundColor))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .overlay(
            // Resize handle indicator
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 8))
                .foregroundColor(Color.gray.opacity(0.3))
                .rotationEffect(.degrees(45))
                .padding(4),
            alignment: .bottomTrailing
        )
        .onAppear {
            ensureSettings()
        }
    }
    
    private func addItem() {
        guard !newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newItem = Item(title: newItemText.trimmingCharacters(in: .whitespacesAndNewlines))
        modelContext.insert(newItem)
        newItemText = ""
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving item: \(error)")
        }
    }
    
    private func ensureSettings() {
        if settingsArray.isEmpty {
            let defaultSettings = Settings()
            modelContext.insert(defaultSettings)
            do {
                try modelContext.save()
            } catch {
                print("Error creating default settings: \(error)")
            }
        }
    }
}

struct TaskRow: View {
    let item: Item
    let settings: Settings?
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    @State private var showDelete = false
    @State private var isEditing = false
    @State private var editingText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private var statusDisplay: String {
        if let settings = settings {
            return settings.getDisplay(for: item.status)
        } else {
            // Default display when no settings exist
            switch item.status {
            case .todo: return "on me"
            case .waiting: return "waiting"
            case .done: return "done"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Status Button
            Button(action: toggleStatus) {
                Text(statusDisplay)
                    .font(.system(size: settings?.useSymbols == true ? 14 : 11, weight: .medium, design: settings?.useSymbols == true ? .monospaced : .default))
                    .frame(minWidth: settings?.useSymbols == true ? 20 : 50, minHeight: 20)
                    .padding(.horizontal, settings?.useSymbols == true ? 0 : 6)
                    .background(statusBackgroundColor)
                    .foregroundColor(statusForegroundColor)
            }
            .buttonStyle(.plain)
            
            // Task Title
            if isEditing {
                TextField("Task", text: $editingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        saveEdit()
                    }
                    .onExitCommand {
                        cancelEdit()
                    }
            } else {
                Text(item.title)
                    .font(.system(size: 13))
                    .foregroundColor(item.status == .done ? .secondary : .primary)
                    .strikethrough(item.status == .done)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .onTapGesture {
                        startEditing()
                    }
            }
            
            // Delete Button - show for completed tasks or on hover with delay (but not when editing)
            if !isEditing && (item.status == .done || (isHovered && showDelete)) {
                Button(action: deleteItem) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.25))
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.8 : 0.5))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
                if hovering && item.status != .done {
                    // Show delete button after 2 second delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if isHovered {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDelete = true
                            }
                        }
                    }
                } else if !hovering {
                    showDelete = false
                }
            }
        }
    }
    
    private var statusBackgroundColor: Color {
        Color(NSColor.controlBackgroundColor).opacity(0.8)
    }
    
    private var statusForegroundColor: Color {
        Color.primary
    }
    
    private func toggleStatus() {
        switch item.status {
        case .todo:
            item.status = .waiting
        case .waiting:
            item.status = .done
        case .done:
            item.status = .todo
        }
        item.updatedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Error updating item: \(error)")
        }
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting item: \(error)")
        }
    }
    
    private func startEditing() {
        editingText = item.title
        isEditing = true
        isTextFieldFocused = true
    }
    
    private func saveEdit() {
        let trimmedText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            item.title = trimmedText
            item.updatedAt = Date()
            
            do {
                try modelContext.save()
            } catch {
                print("Error updating item: \(error)")
            }
        }
        isEditing = false
        isTextFieldFocused = false
    }
    
    private func cancelEdit() {
        isEditing = false
        isTextFieldFocused = false
        editingText = item.title
    }
}

#Preview {
    MenuBarView()
        .modelContainer(for: Item.self, inMemory: true)
}
