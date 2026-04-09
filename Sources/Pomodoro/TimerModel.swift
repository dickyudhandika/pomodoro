import Foundation
import Combine
import UserNotifications
import AppKit
import SwiftUI

extension Phase {
    var accentNSColor: NSColor {
        switch self {
        case .work:       return NSColor(red: 0.910, green: 0.298, blue: 0.239, alpha: 1) // E84C3D
        case .shortBreak: return NSColor(red: 0.251, green: 0.722, blue: 0.486, alpha: 1) // 40B87C
        case .longBreak:  return NSColor(red: 0.251, green: 0.502, blue: 0.922, alpha: 1) // 4080EB
        }
    }
}

enum Phase: String, CaseIterable {
    case work = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    var duration: TimeInterval {
        switch self {
        case .work:       return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak:  return 15 * 60
        }
    }

    var color: String {
        switch self {
        case .work:       return "PomodoroRed"
        case .shortBreak: return "PomodoroGreen"
        case .longBreak:  return "PomodoroBlue"
        }
    }
}

class TimerModel: ObservableObject {
    @Published var phase: Phase = .work
    @Published var timeRemaining: TimeInterval = Phase.work.duration
    @Published var isRunning = false
    @Published var completedPomodoros = 0
    @Published var taskName: String = ""
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    @Published var breakEnded: Bool = false

    let store = SessionStore()

    private var timer: AnyCancellable?
    private var startDate: Date?
    private var sessionTaskName: String = ""
    private var elapsedBeforePause: TimeInterval = 0
    private var startedWithRemaining: TimeInterval = 0

    var progress: Double {
        1.0 - (timeRemaining / phase.duration)
    }

    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// True when a work task is actively being tracked (session started or running with a task name)
    var hasActiveTask: Bool {
        phase == .work && ((isRunning && !taskName.isEmpty) || !sessionTaskName.isEmpty)
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        breakEnded = false

        // Detect task name change during a pause (work phase only)
        if phase == .work && !sessionTaskName.isEmpty && sessionTaskName != taskName {
            if elapsedBeforePause >= 60 {
                store.add(Session(
                    id: UUID(), completedAt: Date(), phaseRaw: phase.rawValue,
                    taskName: sessionTaskName, wasSkipped: false, elapsedSeconds: elapsedBeforePause
                ))
            }
            elapsedBeforePause = 0
        }
        if phase == .work { sessionTaskName = taskName }

        startedWithRemaining = timeRemaining
        isRunning = true
        let remaining = timeRemaining
        startDate = Date()
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.startDate else { return }
                let elapsed = Date().timeIntervalSince(start)
                let newRemaining = remaining - elapsed
                if newRemaining <= 0 {
                    self.complete()
                } else {
                    self.timeRemaining = newRemaining
                }
            }
    }

    func pause() {
        isRunning = false
        timer?.cancel()
        timer = nil
        startDate = nil
        elapsedBeforePause += max(0, startedWithRemaining - timeRemaining)
    }

    func reset() {
        pause()
        timeRemaining = phase.duration
        sessionTaskName = ""; elapsedBeforePause = 0; startedWithRemaining = 0
    }

    func skip() {
        complete(skipped: true)
    }

    /// Log the current task to analytics and clear it, but keep the pomodoro timer running.
    func stopTask() {
        guard phase == .work else { return }
        let currentSegment: TimeInterval = isRunning ? max(0, startedWithRemaining - timeRemaining) : 0
        let totalElapsed = elapsedBeforePause + currentSegment
        let name = sessionTaskName.isEmpty ? taskName : sessionTaskName
        if !name.isEmpty && totalElapsed >= 5 {
            store.add(Session(
                id: UUID(), completedAt: Date(), phaseRaw: phase.rawValue,
                taskName: name, wasSkipped: false, elapsedSeconds: totalElapsed
            ))
        }
        sessionTaskName = ""
        taskName = ""
        elapsedBeforePause = 0
        if isRunning {
            // Reset elapsed tracking so the next task's time is measured from now
            startedWithRemaining = timeRemaining
            startDate = Date()
        }
    }

    private func complete(skipped: Bool = false) {
        pause()  // accumulates final segment into elapsedBeforePause
        let name = (phase == .work && !sessionTaskName.isEmpty) ? sessionTaskName : taskName
        let elapsed: TimeInterval? = elapsedBeforePause > 0 ? elapsedBeforePause : nil
        store.add(Session(
            id: UUID(),
            completedAt: Date(),
            phaseRaw: phase.rawValue,
            taskName: name,
            wasSkipped: skipped,
            elapsedSeconds: elapsed
        ))
        sessionTaskName = ""; elapsedBeforePause = 0; startedWithRemaining = 0
        if phase == .work && !skipped {
            completedPomodoros += 1
        }
        if (phase == .shortBreak || phase == .longBreak) && !skipped {
            breakEnded = true
        }
        sendNotification(for: phase)
        if soundEnabled {
            if let sound = NSSound(named: .init("Funk")) {
                sound.volume = 1.0
                sound.play()
            }
        }
        advance()
    }

    private func advance() {
        switch phase {
        case .work:
            phase = (completedPomodoros % 4 == 0) ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .work
        }
        timeRemaining = phase.duration
    }

    func select(phase: Phase) {
        pause()
        self.phase = phase
        timeRemaining = phase.duration
        sessionTaskName = ""; elapsedBeforePause = 0; startedWithRemaining = 0
    }

    private func sendNotification(for completedPhase: Phase) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch completedPhase {
        case .work:
            content.title = taskName.isEmpty ? "Pomodoro complete!" : "\u{201C}\(taskName)\u{201D} done!"
            content.body = (completedPomodoros % 4 == 0) ? "Time for a long break." : "Time for a short break."
        case .shortBreak:
            content.title = "Break over! Time to focus."
            content.body = "Ready to focus?"
            content.categoryIdentifier = "BREAK_END"
        case .longBreak:
            content.title = "Long break over! Time to focus."
            content.body = "Back to work!"
            content.categoryIdentifier = "BREAK_END"
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
