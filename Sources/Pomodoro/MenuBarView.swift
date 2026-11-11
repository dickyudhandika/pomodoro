import SwiftUI

/// Menu bar popover: one slim row (task title + round start/pause button).
/// Tapping the row body opens a dropdown to add, remove and pick tasks/subtasks.
/// Deliberately no animation anywhere.
struct MenuBarView: View {
    @ObservedObject var model: TimerModel
    @ObservedObject var tasks: TaskStore
    var openAnalytics: () -> Void = {}

    @Environment(\.colorScheme) var scheme
    @State private var expanded = false
    @State private var hoveredID: UUID?
    @State private var newTask = ""
    @State private var addingSubtaskTo: UUID?
    @State private var newSubtask = ""
    @FocusState private var focus: Field?

    private enum Field: Hashable { case newTask, newSubtask }

    private let width: CGFloat = 280
    private let rowHeight: CGFloat = 28
    private let maxVisibleRows = 12

    var t: ShadTheme { scheme == .dark ? .dark : .light }

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            if expanded {
                divider
                taskList
                divider
                footer
            }
        }
        .frame(width: width)
        .background(t.background)
        .transaction { $0.animation = nil }
    }

    private var divider: some View {
        Rectangle().fill(t.border).frame(height: 1)
    }

    // MARK: - Main row

    private var mainRow: some View {
        HStack(spacing: 8) {
            Button(action: { expanded.toggle() }) {
                HStack(spacing: 6) {
                    title
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(t.mutedFg)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: { model.toggle() }) {
                Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(model.phase.accent))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(model.isRunning ? "Pause" : "Start")
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(height: 46)
    }

    @ViewBuilder
    private var title: some View {
        if model.phase.isBreak {
            Text(model.phase.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(model.phase.accent)
        } else if model.taskName.isEmpty {
            Text("Select a task")
                .font(.system(size: 13))
                .foregroundStyle(t.mutedFg)
        } else {
            Text(model.taskName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(t.foreground)
        }
    }

    // MARK: - Task list

    @ViewBuilder
    private var taskList: some View {
        let rows = visibleRowCount
        if rows > maxVisibleRows {
            ScrollView { taskListContent }
                .frame(height: CGFloat(maxVisibleRows) * rowHeight + 8)
        } else {
            taskListContent
        }
    }

    private var visibleRowCount: Int {
        tasks.tasks.reduce(1) { $0 + 1 + $1.subtasks.count } + (addingSubtaskTo == nil ? 0 : 1)
    }

    private var taskListContent: some View {
        VStack(spacing: 0) {
            ForEach(tasks.tasks) { task in
                taskRow(task, isSub: false)
                ForEach(task.subtasks) { sub in
                    taskRow(sub, isSub: true)
                }
                if addingSubtaskTo == task.id {
                    inputRow(placeholder: "Add subtask…", text: $newSubtask, field: .newSubtask, indent: 34) {
                        tasks.addSubtask(newSubtask, to: task.id)
                        newSubtask = ""
                        addingSubtaskTo = nil
                    } onCancel: {
                        newSubtask = ""
                        addingSubtaskTo = nil
                    }
                }
            }
            inputRow(placeholder: "Add task…", text: $newTask, field: .newTask, indent: 20) {
                tasks.addTask(newTask)
                newTask = ""
                focus = .newTask
            } onCancel: {
                newTask = ""
            }
        }
        .padding(.vertical, 4)
    }

    private func taskRow(_ item: TaskItem, isSub: Bool) -> some View {
        let selected = tasks.selectedID == item.id
        let hovered = hoveredID == item.id

        return HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(model.phase.accent)
                .opacity(selected ? 1 : 0)
                .frame(width: 12)

            Text(item.title)
                .font(.system(size: 12, weight: isSub ? .regular : .medium))
                .foregroundStyle(isSub ? t.mutedFg : t.foreground)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, isSub ? 14 : 0)

            Spacer(minLength: 4)

            if hovered {
                if !isSub {
                    rowIcon("plus", help: "Add subtask") {
                        newSubtask = ""
                        addingSubtaskTo = item.id
                        focus = .newSubtask
                    }
                }
                rowIcon("xmark", help: "Remove") { remove(item.id) }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovered ? t.muted : Color.clear)
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture { pick(item.id) }
        .onHover { inside in
            if inside { hoveredID = item.id } else if hoveredID == item.id { hoveredID = nil }
        }
    }

    private func rowIcon(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(t.mutedFg)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func inputRow(placeholder: String, text: Binding<String>, field: Field, indent: CGFloat,
                          onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(t.foreground)
            .focused($focus, equals: field)
            .onSubmit(onSubmit)
            .onExitCommand(perform: onCancel)
            .padding(.leading, indent)
            .padding(.trailing, 14)
            .frame(height: rowHeight)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 2) {
            if model.phase.isBreak {
                textButton("Skip break") { model.skip() }
            } else if model.inSession {
                textButton("Stop") { model.stop() }
            }

            Spacer()

            footerIcon("chart.bar", help: "Analytics") { openAnalytics() }
            footerIcon(model.soundEnabled ? "speaker.wave.2" : "speaker.slash",
                       help: model.soundEnabled ? "Sound on" : "Sound off") {
                model.soundEnabled.toggle()
            }
            footerIcon("power", help: "Quit") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
    }

    private func textButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(model.phase.accent)
                .padding(.horizontal, 6)
                .frame(height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func footerIcon(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(t.mutedFg)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Actions

    private func pick(_ id: UUID) {
        if tasks.selectedID != id {
            tasks.select(id: id)
            model.selectTask(name: tasks.selectedName)
        }
        expanded = false
    }

    private func remove(_ id: UUID) {
        if addingSubtaskTo == id { addingSubtaskTo = nil }
        let hadSelection = tasks.selectedID != nil
        tasks.remove(id: id)
        if hadSelection && tasks.selectedID == nil {
            model.selectTask(name: "")
        }
    }
}
