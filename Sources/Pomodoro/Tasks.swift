import Foundation

struct TaskItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var subtasks: [TaskItem] = []
}

/// Two-level task list (tasks + subtasks) and the current selection, persisted in UserDefaults.
class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var selectedID: UUID?

    private let tasksKey = "pomodoro.tasks"
    private let selectedKey = "pomodoro.selectedTask"

    init() { load() }

    // MARK: - Editing

    /// Adds a top-level task and returns its id (nil if the title is blank).
    @discardableResult
    func addTask(_ title: String) -> UUID? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let item = TaskItem(title: t)
        tasks.append(item)
        save()
        return item.id
    }

    func addSubtask(_ title: String, to parentID: UUID) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let i = tasks.firstIndex(where: { $0.id == parentID }) else { return }
        tasks[i].subtasks.append(TaskItem(title: t))
        save()
    }

    /// Removes a task or subtask. Removing a parent removes its subtasks.
    /// If the selection disappears with it, the selection is cleared.
    func remove(id: UUID) {
        if let i = tasks.firstIndex(where: { $0.id == id }) {
            tasks.remove(at: i)
        } else {
            for i in tasks.indices {
                tasks[i].subtasks.removeAll { $0.id == id }
            }
        }
        if let sel = selectedID, path(for: sel) == nil {
            selectedID = nil
        }
        save()
    }

    func select(id: UUID?) {
        selectedID = id
        save()
    }

    // MARK: - Names

    /// The string recorded in analytics: "Title" or "Parent › Sub". Empty when nothing is selected.
    var selectedName: String {
        guard let id = selectedID, let p = path(for: id) else { return "" }
        return p.map(\.title).joined(separator: " › ")
    }

    private func path(for id: UUID) -> [TaskItem]? {
        for task in tasks {
            if task.id == id { return [task] }
            if let sub = task.subtasks.first(where: { $0.id == id }) { return [task, sub] }
        }
        return nil
    }

    // MARK: - Persistence

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(tasks) {
            d.set(data, forKey: tasksKey)
        }
        d.set(selectedID?.uuidString, forKey: selectedKey)
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
        }
        if let s = d.string(forKey: selectedKey), let id = UUID(uuidString: s), path(for: id) != nil {
            selectedID = id
        }
    }
}
