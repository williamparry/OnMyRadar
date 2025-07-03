import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes
    @Query(sort: \Item.order) private var items: [Item]
    @Query private var settingsArray: [Settings]
    @State private var newItemText = ""
    @State private var shouldRotateRadar = false
    @State private var editingTaskId: PersistentIdentifier? = nil
    @State private var isEditMode = false
    @State private var isPanelActive = true
    @State private var showClearOptions = false
    @State private var allowTaskFocus = false
    @FocusState private var isInputFocused: Bool
    @FocusState private var isTaskListFocused: Bool
    @FocusState private var isEditButtonFocused: Bool
    @FocusState private var isClearButtonFocused: Bool
    @FocusState private var isSettingsButtonFocused: Bool
    @FocusState private var isClearAllFocused: Bool
    @FocusState private var isClearDoneFocused: Bool
    
    private var settings: Settings? {
        settingsArray.first
    }
    
    var body: some View {
        ZStack {
            radarBackground
            mainContent
        }
        .background(colorScheme == .light ? Color.white.opacity(0.95) : Color.black.opacity(0.85))
        .preferredColorScheme(colorScheme)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(borderOverlay)
        .overlay(resizeHandleOverlay, alignment: .bottomTrailing)
        .onAppear {
            ensureSettings()
            // Delay allowing task focus to prevent initial highlight
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                allowTaskFocus = true
                // Set initial focus to the hidden task list element
                isTaskListFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PanelDidBecomeActive"))) { _ in
            isPanelActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PanelDidBecomeInactive"))) { _ in
            isPanelActive = false
            isEditMode = false
        }
        .onKeyPress { key in
            handleGlobalKeyPress(key)
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
            toolbar
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
            VStack(spacing: 0) {
                // Hidden focusable element for "Task List" tab stop
                Text(isEditMode ? "Edit Task List" : "Task List")
                    .font(.caption)
                    .frame(width: 1, height: 1)
                    .offset(x: -9999, y: -9999)
                    .focusable()
                    .focused($isTaskListFocused)
                    .accessibilityLabel(isEditMode ? "Edit task list" : "Task list")
                    .accessibilityHint(isEditMode ? "Tab through the tasks to reorder or delete" : "Tab through the tasks below")
                    .onChange(of: isEditMode) { _, newValue in
                        if newValue {
                            // Ensure focus goes to task list when entering edit mode
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTaskListFocused = true
                                // Move VoiceOver focus to this element
                                if let window = NSApp.mainWindow {
                                    NSAccessibility.post(element: window, notification: .focusedUIElementChanged)
                                }
                            }
                        }
                    }
                
                taskListContent
            }
        }
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            isInputFocused = false
            editingTaskId = nil
        }
    }
    
    private var taskListContent: some View {
        VStack(spacing: 6) {
            ForEach(items) { item in
                TaskRow(
                    item: item,
                    settings: settings,
                    isEditMode: isEditMode,
                    allowTaskFocus: allowTaskFocus,
                    onEditingChanged: { isEditing in
                        if isEditing {
                            editingTaskId = item.id
                        } else if editingTaskId == item.id {
                            editingTaskId = nil
                        }
                    },
                    editingTaskId: editingTaskId
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    
    
    private var newTaskInput: some View {
        HStack {
            TextField("New task", text: $newItemText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isInputFocused)
                .onSubmit {
                    addItem()
                }
                .disabled(false)
                .accessibilityLabel("New task input")
                .accessibilityHint("Type a task and press return to add it")
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
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditMode.toggle()
                }
            }) {
                Text(isEditMode ? "Done" : "Edit")
                    .font(.caption)
                    .foregroundColor(items.isEmpty ? Color.secondary.opacity(0.5) : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(items.isEmpty)
            .accessibilityLabel(isEditMode ? "Finish editing" : "Edit tasks")
            .accessibilityHint(isEditMode ? "Tap to exit edit mode" : "Tap to reorder or delete tasks")
            .focusable(!items.isEmpty)
            .focused($isEditButtonFocused)
            .onKeyPress { key in
                if key.key == .space || key.key == .return {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditMode.toggle()
                    }
                    return .handled
                }
                return .ignored
            }
            
            Spacer()
            
            Button(action: {
                showClearOptions.toggle()
            }) {
                Text("Clear Tasks")
                    .font(.caption)
                    .foregroundColor(items.isEmpty ? Color.secondary.opacity(0.5) : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(items.isEmpty)
            .accessibilityLabel("Clear tasks menu")
            .accessibilityHint("Tap to show options for clearing tasks")
            .focusable(!items.isEmpty)
            .focused($isClearButtonFocused)
            .onKeyPress { key in
                if key.key == .space || key.key == .return {
                    showClearOptions.toggle()
                    return .handled
                }
                return .ignored
            }
            .popover(isPresented: $showClearOptions) {
                VStack(spacing: 0) {
                    Button(action: {
                        showClearOptions = false
                        NotificationCenter.default.post(name: NSNotification.Name("ClearAllTasks"), object: nil)
                    }) {
                        HStack {
                            Text("Clear all tasks")
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .focused($isClearAllFocused)
                    .onKeyPress { key in
                        if key.key == .space || key.key == .return {
                            showClearOptions = false
                            NotificationCenter.default.post(name: NSNotification.Name("ClearAllTasks"), object: nil)
                            return .handled
                        }
                        return .ignored
                    }
                    .accessibilityLabel("Clear all tasks")
                    .accessibilityHint("Press return or space to clear all tasks")
                    
                    Divider()
                        .padding(.horizontal, 8)
                    
                    Button(action: {
                        showClearOptions = false
                        NotificationCenter.default.post(name: NSNotification.Name("ClearDoneTasks"), object: nil)
                    }) {
                        HStack {
                            Text("Clear done tasks")
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .focused($isClearDoneFocused)
                    .onKeyPress { key in
                        if key.key == .space || key.key == .return {
                            showClearOptions = false
                            NotificationCenter.default.post(name: NSNotification.Name("ClearDoneTasks"), object: nil)
                            return .handled
                        }
                        return .ignored
                    }
                    .accessibilityLabel("Clear done tasks")
                    .accessibilityHint("Press return or space to clear only completed tasks")
                }
                .frame(width: 160)
                .onAppear {
                    // Focus the first button when popover appears
                    isClearAllFocused = true
                }
            }
            
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsWindow"), object: nil)
            }) {
                Text("Settings")
                    .font(.caption)
                    .foregroundColor(Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open settings")
            .accessibilityHint("Tap to open application settings")
            .focusable(true)
            .focused($isSettingsButtonFocused)
            .onKeyPress { key in
                if key.key == .space || key.key == .return {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsWindow"), object: nil)
                    return .handled
                }
                return .ignored
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .opacity(isPanelActive ? 1 : 0)
        .allowsHitTesting(isPanelActive)
    }
    
    private func addItem() {
        guard !newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let maxOrder = items.map { $0.order }.max() ?? -1
        let newItem = Item(title: newItemText.trimmingCharacters(in: .whitespacesAndNewlines), order: maxOrder + 1)
        modelContext.insert(newItem)
        newItemText = ""
        
        shouldRotateRadar = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            shouldRotateRadar = false
        }
        
        do {
            try modelContext.save()
        } catch {
        }
    }
    
    private func ensureSettings() {
        if settingsArray.isEmpty {
            let defaultSettings = Settings()
            modelContext.insert(defaultSettings)
            do {
                try modelContext.save()
            } catch {
            }
        }
        
        let itemsNeedingOrder = items.filter { $0.order == 0 }
        if !itemsNeedingOrder.isEmpty {
            for (index, item) in items.enumerated() {
                item.order = index
            }
            do {
                try modelContext.save()
            } catch {
            }
        }
    }
    
    private func handleGlobalKeyPress(_ key: KeyPress) -> KeyPress.Result {
        if key.modifiers.contains(.command) {
            switch key.key {
            case KeyEquivalent("n"):
                isInputFocused = true
                return .handled
            case KeyEquivalent("e"):
                if !items.isEmpty {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditMode.toggle()
                    }
                }
                return .handled
            case KeyEquivalent(","):
                NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsWindow"), object: nil)
                return .handled
            default:
                break
            }
        }
        
        // Tab navigation is handled automatically by SwiftUI
        
        return .ignored
    }
}

#Preview {
    MenuBarView()
        .modelContainer(for: Item.self, inMemory: true)
}

struct TaskRow: View {
    let item: Item
    let settings: Settings?
    let isEditMode: Bool
    let allowTaskFocus: Bool
    var onEditingChanged: ((Bool) -> Void)?
    var editingTaskId: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes
    @Query(sort: \Item.order) private var allItems: [Item]
    @State private var isEditing = false
    @State private var editingText = ""
    @State private var allowDeleteFocus = false
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isFocused: Bool
    @FocusState private var isMoveUpFocused: Bool
    @FocusState private var isMoveDownFocused: Bool
    @FocusState private var isStatusFocused: Bool
    @FocusState private var isTaskTextFocused: Bool
    @FocusState private var isDeleteFocused: Bool
    
    private var statusDisplay: String {
        if let settings = settings {
            return settings.getDisplay(for: item.status)
        }
        switch item.status {
        case .todo: return "on me"
        case .waiting: return "waiting"
        case .done: return "done"
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
            if !isEditing && isEditMode {
                reorderButtons
            }
            
            statusButton
            
            if isEditing {
                editField
            } else {
                taskText
            }
            
            if !isEditing && (item.status == .done || isEditMode) {
                deleteButton
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.08))
        .contentShape(Rectangle())
        .focusable(allowTaskFocus)
        .focused($isFocused)
        .onKeyPress { key in
            handleKeyPress(key)
        }
        .onTapGesture {
            if isEditing {
                saveEdit()
            }
        }
        .accessibilityElement(children: isEditMode ? .contain : .combine)
        .accessibilityLabel(isEditMode ? "" : "\(item.title), status: \(statusDisplay)")
        .accessibilityHint(isEditMode ? "" : "Press space to change status, return to edit")
        .overlay(focusOverlay)
        .accessibilityAddTraits(isFocused ? .isSelected : [])
        .onChange(of: editingTaskId) { _, newValue in
            if isEditing && newValue != item.id {
                saveEdit()
            }
        }
        .onChange(of: isEditMode) { _, newValue in
            if newValue {
                // Delay allowing delete focus to prevent it from stealing focus
                allowDeleteFocus = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    allowDeleteFocus = true
                }
            } else {
                allowDeleteFocus = false
            }
        }
    }
    
    @ViewBuilder
    private var focusOverlay: some View {
        if isFocused && showButtonShapes {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.accentColor, lineWidth: 2)
                .padding(-2)
        }
    }
    
    @ViewBuilder
    private var reorderButtons: some View {
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
            .focusable(canMoveUp)
            .focused($isMoveUpFocused)
            .onKeyPress { key in
                if key.key == .space || key.key == .return {
                    moveItemUp()
                    return .handled
                }
                return .ignored
            }
            .accessibilityLabel("Move task up")
            .accessibilityHint("Press return or space to move this task up in the list")
            .overlay(
                isMoveUpFocused && showButtonShapes ?
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .padding(-1) : nil
            )
            
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
            .focusable(canMoveDown)
            .focused($isMoveDownFocused)
            .onKeyPress { key in
                if key.key == .space || key.key == .return {
                    moveItemDown()
                    return .handled
                }
                return .ignored
            }
            .accessibilityLabel("Move task down")
            .accessibilityHint("Press return or space to move this task down in the list")
            .overlay(
                isMoveDownFocused && showButtonShapes ?
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .padding(-1) : nil
            )
        }
        .transition(.opacity)
    }
    
    private var statusButton: some View {
        Button(action: toggleStatus) {
            Text(statusDisplay)
                .font(.system(size: settings?.useSymbols == true ? 14 : 11, weight: .medium, design: settings?.useSymbols == true ? .monospaced : .default))
                .frame(minWidth: settings?.useSymbols == true ? 20 : 50, minHeight: 20)
                .padding(.horizontal, settings?.useSymbols == true ? 0 : 6)
                .background(statusBackgroundColor)
                .foregroundColor(statusForegroundColor)
        }
        .buttonStyle(.plain)
        .focusable(isEditMode)
        .focused($isStatusFocused)
        .onKeyPress { key in
            if isEditMode && (key.key == .space || key.key == .return) {
                toggleStatus()
                return .handled
            }
            return .ignored
        }
        .accessibilityLabel("Task status: \(statusDisplay)")
        .accessibilityHint("Press space or return to cycle through status options")
        .overlay(
            isStatusFocused && showButtonShapes ?
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .padding(-2) : nil
        )
    }
    
    private var editField: some View {
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
    }
    
    private var taskText: some View {
        Text(item.title)
            .font(.system(size: 13))
            .foregroundColor(item.status == .done ? .secondary : .primary)
            .strikethrough(item.status == .done)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .onTapGesture {
                startEditing()
            }
            .focusable(isEditMode)
            .focused($isTaskTextFocused)
            .onKeyPress { key in
                if isEditMode && (key.key == .space || key.key == .return) {
                    startEditing()
                    return .handled
                }
                return .ignored
            }
            .accessibilityLabel("Task: \(item.title)")
            .accessibilityHint(isEditMode ? "Press return or space to edit this task" : "")
            .overlay(
                isTaskTextFocused && showButtonShapes ?
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .padding(-2) : nil
            )
    }
    
    private var deleteButton: some View {
        Button(action: deleteItem) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary.opacity(0.25))
                .imageScale(.medium)
        }
        .buttonStyle(.plain)
        .transition(.opacity)
        .focusable(isEditMode && allowDeleteFocus)
        .focused($isDeleteFocused)
        .onKeyPress { key in
            if key.key == .space || key.key == .return {
                deleteItem()
                return .handled
            }
            return .ignored
        }
        .accessibilityLabel("Delete task")
        .accessibilityHint("Press return or space to remove this task")
        .overlay(
            isDeleteFocused && showButtonShapes ?
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .padding(-2) : nil
        )
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
        
        // Announce the status change to VoiceOver
        let newStatus = statusDisplay
        NSAccessibility.post(element: NSApp.mainWindow!, notification: .announcementRequested, userInfo: [.announcement: "Status changed to \(newStatus)"])
        
        do {
            try modelContext.save()
        } catch {
        }
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        
        do {
            try modelContext.save()
        } catch {
        }
    }
    
    private func moveItemUp() {
        guard let currentIndex = allItems.firstIndex(where: { $0.id == item.id }),
              currentIndex > 0 else { return }
        
        let previousIndex = currentIndex - 1
        let tempOrder = allItems[currentIndex].order
        allItems[currentIndex].order = allItems[previousIndex].order
        allItems[previousIndex].order = tempOrder
        
        do {
            try modelContext.save()
        } catch {
        }
    }
    
    private func moveItemDown() {
        guard let currentIndex = allItems.firstIndex(where: { $0.id == item.id }),
              currentIndex < allItems.count - 1 else { return }
        
        let nextIndex = currentIndex + 1
        let tempOrder = allItems[currentIndex].order
        allItems[currentIndex].order = allItems[nextIndex].order
        allItems[nextIndex].order = tempOrder
        
        do {
            try modelContext.save()
        } catch {
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
    
    private func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
        // In edit mode, let individual controls handle their own keyboard events
        if isEditMode {
            return .ignored
        }
        
        switch key.key {
        case .space:
            toggleStatus()
            return .handled
        case .return:
            if !isEditing {
                startEditing()
                return .handled
            }
            return .ignored
        case .delete, .deleteForward:
            if !isEditing && !isEditMode {
                deleteItem()
                return .handled
            }
            return .ignored
        default:
            return .ignored
        }
    }
}

#Preview {
    MenuBarView()
        .modelContainer(for: Item.self, inMemory: true)
}
