import Foundation

struct Session: Identifiable, Codable {
    let id: UUID
    let completedAt: Date
    let phaseRaw: String
    let taskName: String
    let wasSkipped: Bool
    let elapsedSeconds: TimeInterval?  // nil = use phase default; populated for partial and tracked sessions
    /// true only for a fully completed focus phase; false for task-switch / Stop segments.
    /// nil on records saved before this field existed (counted as before: any unskipped focus session).
    var countsAsPomodoro: Bool? = nil

    var phase: Phase? { Phase(rawValue: phaseRaw) }

    var durationMinutes: Int {
        if let e = elapsedSeconds { return max(1, Int(e / 60)) }
        switch phaseRaw {
        case Phase.work.rawValue:       return 25
        case Phase.shortBreak.rawValue: return 5
        case Phase.longBreak.rawValue:  return 15
        default: return 0
        }
    }
}

class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []

    private let key = "pomodoro.sessions"

    init() { load() }

    func add(_ session: Session) {
        sessions.append(session)
        save()
    }

    func clear() {
        sessions = []
        save()
    }

    // MARK: - Stats helpers

    var todaySessions: [Session] {
        let start = Calendar.current.startOfDay(for: Date())
        return sessions.filter { $0.completedAt >= start }
    }

    var todayFocusMinutes: Int {
        todaySessions.filter { $0.phaseRaw == Phase.work.rawValue && !$0.wasSkipped }
                     .reduce(0) { $0 + $1.durationMinutes }
    }

    var todayPomodoros: Int {
        todaySessions.filter {
            $0.phaseRaw == Phase.work.rawValue && !$0.wasSkipped && ($0.countsAsPomodoro ?? true)
        }.count
    }

    var uniqueTasksToday: [String] {
        let names = todaySessions
            .filter { $0.phaseRaw == Phase.work.rawValue && !$0.taskName.isEmpty }
            .map { $0.taskName }
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    /// Sessions grouped by calendar day, newest day first
    var grouped: [(day: Date, sessions: [Session])] {
        let cal = Calendar.current
        let byDay = Dictionary(grouping: sessions) { cal.startOfDay(for: $0.completedAt) }
        return byDay.keys.sorted(by: >).map { day in
            (day: day, sessions: byDay[day]!.sorted { $0.completedAt > $1.completedAt })
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Session].self, from: data) else { return }
        sessions = decoded
    }
}
