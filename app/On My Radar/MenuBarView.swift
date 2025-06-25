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
    @Query(sort: \Item.order) private var items: [Item]
    @Query private var settingsArray: [Settings]
    @State private var newItemText = ""
    @FocusState private var isInputFocused: Bool
    @State private var shouldRotateRadar = false
    @State private var editingTaskId: PersistentIdentifier? = nil
    @State private var recentlyReorderedId: PersistentIdentifier? = nil
    var onTaskCountChanged: ((Int) -> Void)?
    
    private var settings: Settings? {
        settingsArray.first
    }
    
    var body: some View {
        ZStack {
            radarBackground
            mainContent
        }
        .background(Color.black.opacity(0.85))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(borderOverlay)
        .overlay(resizeHandleOverlay, alignment: .bottomTrailing)
        .onAppear {
            ensureSettings()
            updateTaskCount()
        }
        .onChange(of: items.count) { _, _ in
            updateTaskCount()
        }
        .onChange(of: items.map { $0.status }) { _, _ in
            updateTaskCount()
        }
    }
    
    private var radarBackground: some View {
        RadarBackground(shouldRotate: shouldRotateRadar)
            .allowsHitTesting(false)
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            dragArea
            taskList
            Divider()
                .opacity(0.5)
            newTaskInput
        }
    }
    
    private var dragArea: some View {
        Color.clear
            .frame(height: 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.001))
    }
    
    private var taskList: some View {
        ScrollView {
            taskListContent
        }
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            // Unfocus text field when clicking outside
            isInputFocused = false
            // This will trigger any editing task to save via onEditingChanged
            editingTaskId = nil
        }
    }
    
    private var taskListContent: some View {
        VStack(spacing: 6) {
            ForEach(items) { item in
                taskRowFor(item)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    
    private func taskRowFor(_ item: Item) -> some View {
        TaskRow(
            item: item,
            settings: settings,
            onEditingChanged: { isEditing in
                if isEditing {
                    editingTaskId = item.id
                } else if editingTaskId == item.id {
                    editingTaskId = nil
                }
            },
            editingTaskId: editingTaskId,
            recentlyReorderedId: $recentlyReorderedId
        )
    }
    
    private var newTaskInput: some View {
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
        .background(Color.white.opacity(0.08))
    }
    
    private var borderOverlay: some View {
        Rectangle()
            .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
    }
    
    private var resizeHandleOverlay: some View {
        Image(systemName: "line.3.horizontal.decrease")
            .font(.system(size: 8))
            .foregroundColor(Color.black.opacity(0.2))
            .rotationEffect(.degrees(45))
            .padding(4)
    }
    
    private func addItem() {
        guard !newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Find the highest order value
        let maxOrder = items.map { $0.order }.max() ?? -1
        let newItem = Item(title: newItemText.trimmingCharacters(in: .whitespacesAndNewlines), order: maxOrder + 1)
        modelContext.insert(newItem)
        newItemText = ""
        
        // Trigger radar rotation
        shouldRotateRadar = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            shouldRotateRadar = false
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving item: \(error)")
        }
    }
    
    private func updateTaskCount() {
        let pendingCount = items.filter { $0.status != .done }.count
        onTaskCountChanged?(pendingCount)
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
        
        // Ensure all items have an order value
        let itemsNeedingOrder = items.filter { $0.order == 0 }
        if !itemsNeedingOrder.isEmpty {
            for (index, item) in items.enumerated() {
                item.order = index
            }
            do {
                try modelContext.save()
            } catch {
                print("Error updating item order: \(error)")
            }
        }
    }
}

struct TaskRow: View {
    let item: Item
    let settings: Settings?
    var onEditingChanged: ((Bool) -> Void)?
    var editingTaskId: PersistentIdentifier?
    @Binding var recentlyReorderedId: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.order) private var allItems: [Item]
    @State private var isHovered = false
    @State private var showDelete = false
    @State private var showReorderButtons = false
    @State private var isEditing = false
    @State private var editingText = ""
    @State private var keepControlsTimer: Timer?
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
    
    private var canMoveUp: Bool {
        guard let currentIndex = allItems.firstIndex(where: { $0.id == item.id }) else { return false }
        return currentIndex > 0
    }
    
    private var canMoveDown: Bool {
        guard let currentIndex = allItems.firstIndex(where: { $0.id == item.id }) else { return false }
        return currentIndex < allItems.count - 1
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Reorder Buttons - show on hover with delay (but not when editing)
            if !isEditing && (isHovered || recentlyReorderedId == item.id) && showReorderButtons {
                VStack(spacing: 2) {
                    Button(action: moveItemUp) {
                        Image(systemName: "chevron.up")
                            .foregroundColor(.secondary.opacity(0.7))
                            .font(.system(size: 6, weight: .medium))
                            .frame(width: 14, height: 12)
                            .background(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                            )
                            .cornerRadius(2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveUp)
                    .opacity(canMoveUp ? 1.0 : 0.3)
                    
                    Button(action: moveItemDown) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary.opacity(0.7))
                            .font(.system(size: 6, weight: .medium))
                            .frame(width: 14, height: 12)
                            .background(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                            )
                            .cornerRadius(2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveDown)
                    .opacity(canMoveDown ? 1.0 : 0.3)
                }
                .transition(.opacity)
            }
            
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
            if !isEditing && (item.status == .done || ((isHovered || recentlyReorderedId == item.id) && showDelete)) {
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
        .background(Color.white.opacity(isHovered ? 0.15 : 0.08))
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                saveEdit()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
                if hovering {
                    // Show delete button and reorder buttons after 1 second delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if isHovered || keepControlsTimer != nil {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if item.status != .done {
                                    showDelete = true
                                }
                                showReorderButtons = true
                            }
                        }
                    }
                } else if !hovering {
                    // Only hide controls if we're not in the keep-alive period
                    if keepControlsTimer == nil {
                        showDelete = false
                        showReorderButtons = false
                    }
                }
            }
        }
        .onChange(of: editingTaskId) { _, newValue in
            // If another task started editing, save this one
            if isEditing && newValue != item.id {
                saveEdit()
            }
        }
        .onChange(of: recentlyReorderedId) { _, newValue in
            // If this item was just reordered, show controls immediately
            if newValue == item.id && !showReorderButtons {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDelete = item.status == .done
                    showReorderButtons = true
                }
            }
        }
    }
    
    private var statusBackgroundColor: Color {
        switch item.status {
        case .todo:
            return Color.blue.opacity(0.2)
        case .waiting:
            return Color.orange.opacity(0.2)
        case .done:
            return Color.green.opacity(0.2)
        }
    }
    
    private var statusForegroundColor: Color {
        switch item.status {
        case .todo:
            return Color.blue
        case .waiting:
            return Color.orange
        case .done:
            return Color.green
        }
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
    
    private func moveItemUp() {
        guard let currentIndex = allItems.firstIndex(where: { $0.id == item.id }),
              currentIndex > 0 else { return }
        
        let previousIndex = currentIndex - 1
        
        // Swap order values
        let tempOrder = allItems[currentIndex].order
        allItems[currentIndex].order = allItems[previousIndex].order
        allItems[previousIndex].order = tempOrder
        
        do {
            try modelContext.save()
            keepControlsVisible()
        } catch {
            print("Error moving item up: \(error)")
        }
    }
    
    private func moveItemDown() {
        guard let currentIndex = allItems.firstIndex(where: { $0.id == item.id }),
              currentIndex < allItems.count - 1 else { return }
        
        let nextIndex = currentIndex + 1
        
        // Swap order values
        let tempOrder = allItems[currentIndex].order
        allItems[currentIndex].order = allItems[nextIndex].order
        allItems[nextIndex].order = tempOrder
        
        do {
            try modelContext.save()
            keepControlsVisible()
        } catch {
            print("Error moving item down: \(error)")
        }
    }
    
    private func keepControlsVisible() {
        // Cancel any existing timer
        keepControlsTimer?.invalidate()
        
        // Mark this item as recently reordered
        recentlyReorderedId = item.id
        
        // Keep controls visible
        showDelete = item.status == .done
        showReorderButtons = true
        
        // Set timer to hide controls after 1 second
        keepControlsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            // Only hide if not currently hovered
            if !isHovered {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDelete = false
                    showReorderButtons = false
                    // Clear the recently reordered flag
                    if recentlyReorderedId == item.id {
                        recentlyReorderedId = nil
                    }
                }
            }
            keepControlsTimer = nil
        }
    }
    
    private func startEditing() {
        editingText = item.title
        isEditing = true
        isTextFieldFocused = true
        onEditingChanged?(true)
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
        onEditingChanged?(false)
    }
    
    private func cancelEdit() {
        isEditing = false
        isTextFieldFocused = false
        editingText = item.title
        onEditingChanged?(false)
    }
}

#Preview {
    MenuBarView()
        .modelContainer(for: Item.self, inMemory: true)
}


