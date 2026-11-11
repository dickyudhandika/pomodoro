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

    var isBreak: Bool { self != .work }
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
    /// When the current run (since the last start/resume) began.
    private var startDate: Date?
    /// Time remaining at `startDate`. The countdown is always `remainingAtStart - (now - startDate)`.
    private var remainingAtStart: TimeInterval = Phase.work.duration
    /// Time remaining when the current task segment began. Segment elapsed = this - remaining now.
    /// Switching tasks only moves this marker; it never touches `startDate` or the countdown.
    private var segmentStartRemaining: TimeInterval = Phase.work.duration

    var timeString: String {
        let total = Int(timeRemaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// True when the current phase has been started (running or paused part-way through).
    var inSession: Bool {
        isRunning || timeRemaining < phase.duration
    }

    /// Precise remaining time right now (timeRemaining is only refreshed every 0.5s).
    private var currentRemaining: TimeInterval {
        guard isRunning, let start = startDate else { return timeRemaining }
        return max(0, remainingAtStart - Date().timeIntervalSince(start))
    }

    // MARK: - Controls

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        breakEnded = false
        remainingAtStart = timeRemaining
        startDate = Date()
        isRunning = true
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard isRunning, let start = startDate else { return }
        let newRemaining = remainingAtStart - Date().timeIntervalSince(start)
        if newRemaining <= 0 {
            timeRemaining = 0
            complete()
        } else {
            timeRemaining = newRemaining
        }
    }

    func pause() {
        guard isRunning else { return }
        timeRemaining = currentRemaining
        isRunning = false
        timer?.cancel()
        timer = nil
        startDate = nil
    }

    func reset() {
        pause()
        timeRemaining = phase.duration
        remainingAtStart = phase.duration
        segmentStartRemaining = phase.duration
    }

    /// Ends the current phase early and moves on (used for "Skip break").
    func skip() {
        complete(skipped: true)
    }

    /// Switch the task being tracked. During a focus session the time spent so far is logged
    /// to the previous task and the countdown carries on, uninterrupted, for the new one.
    func selectTask(name: String) {
        if phase == .work {
            logSegment()
            segmentStartRemaining = currentRemaining
        }
        taskName = name
    }

    /// Log the current focus segment, then reset the focus timer.
    func stop() {
        if phase == .work { logSegment() }
        reset()
    }

    // MARK: - Recording

    /// Logs the time spent on the current task since the segment began (≥5s), as a partial focus session.
    private func logSegment() {
        let elapsed = segmentStartRemaining - currentRemaining
        guard elapsed >= 5 else { return }
        store.add(Session(
            id: UUID(), completedAt: Date(), phaseRaw: Phase.work.rawValue,
            taskName: taskName, wasSkipped: false, elapsedSeconds: elapsed,
            countsAsPomodoro: false
        ))
    }

    private func complete(skipped: Bool = false) {
        pause()
        let completed = phase
        let name = taskName
        let elapsed = segmentStartRemaining - timeRemaining
        let isFullFocus = completed == .work && !skipped

        store.add(Session(
            id: UUID(),
            completedAt: Date(),
            phaseRaw: completed.rawValue,
            taskName: completed == .work ? name : "",
            wasSkipped: skipped,
            elapsedSeconds: elapsed > 0 ? elapsed : nil,
            countsAsPomodoro: completed == .work ? isFullFocus : nil
        ))

        if isFullFocus {
            completedPomodoros += 1
        }
        if completed.isBreak && !skipped {
            breakEnded = true
        }
        if !skipped {
            sendNotification(for: completed, taskName: name)
            playSound()
        }

        advance()

        // Breaks start on their own; focus waits for the user.
        if phase.isBreak {
            start()
        }
    }

    private func advance() {
        switch phase {
        case .work:
            phase = (completedPomodoros > 0 && completedPomodoros % 4 == 0) ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .work
        }
        timeRemaining = phase.duration
        remainingAtStart = phase.duration
        segmentStartRemaining = phase.duration
    }

    private func playSound() {
        guard soundEnabled, let sound = NSSound(named: .init("Funk")) else { return }
        sound.volume = 1.0
        sound.play()
    }

    private func sendNotification(for completedPhase: Phase, taskName: String) {
        // UNUserNotificationCenter is only available inside an .app bundle.
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch completedPhase {
        case .work:
            content.title = taskName.isEmpty ? "Pomodoro complete!" : "\u{201C}\(taskName)\u{201D} done!"
            content.body = (completedPomodoros % 4 == 0) ? "Long break started." : "Short break started."
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
