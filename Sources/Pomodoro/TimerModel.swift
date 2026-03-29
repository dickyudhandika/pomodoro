import Foundation
import Combine
import UserNotifications
import AppKit

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

    let store = SessionStore()

    private var timer: AnyCancellable?
    private var startDate: Date?
    private var pausedRemaining: TimeInterval?

    var progress: Double {
        1.0 - (timeRemaining / phase.duration)
    }

    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
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
    }

    func reset() {
        pause()
        timeRemaining = phase.duration
    }

    func skip() {
        complete(skipped: true)
    }

    private func complete(skipped: Bool = false) {
        pause()
        store.add(Session(
            id: UUID(),
            completedAt: Date(),
            phaseRaw: phase.rawValue,
            taskName: taskName,
            wasSkipped: skipped
        ))
        if phase == .work && !skipped {
            completedPomodoros += 1
        }
        sendNotification(for: phase)
        NSSound.beep()
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
    }

    private func sendNotification(for completedPhase: Phase) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch completedPhase {
        case .work:
            content.title = taskName.isEmpty ? "Pomodoro complete!" : "\u{201C}\(taskName)\u{201D} done!"
            content.body = (completedPomodoros % 4 == 0) ? "Time for a long break." : "Time for a short break."
        case .shortBreak:
            content.title = "Break over"
            content.body = "Ready to focus?"
        case .longBreak:
            content.title = "Long break over"
            content.body = "Back to work!"
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
