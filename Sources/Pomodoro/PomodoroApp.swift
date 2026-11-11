import SwiftUI
import AppKit
import UserNotifications
import Combine

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Menu-bar-only app: no main window. The UI lives in the status item popover.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let model = TimerModel()
    let tasks = TaskStore()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var analyticsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.taskName = tasks.selectedName
        setupMenuBar()
        observeModel()
        setupNotifications()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        updateButton()

        let host = NSHostingController(
            rootView: MenuBarView(model: model, tasks: tasks,
                                  openAnalytics: { [weak self] in self?.openAnalytics() })
        )
        // Popover follows the SwiftUI content size, so opening the dropdown resizes it immediately.
        host.sizingOptions = .preferredContentSize

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = host
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }

        if model.inSession {
            // Dot + time whenever a phase is in progress; dimmed while paused.
            let alpha: CGFloat = model.isRunning ? 1 : 0.4
            let dotAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: model.phase.accentNSColor.withAlphaComponent(alpha),
                .font: NSFont.systemFont(ofSize: 8, weight: .medium)
            ]
            var timeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
            ]
            if !model.isRunning {
                timeAttrs[.foregroundColor] = NSColor.secondaryLabelColor
            }
            let s = NSMutableAttributedString(string: "● ", attributes: dotAttrs)
            s.append(NSAttributedString(string: model.timeString, attributes: timeAttrs))
            button.attributedTitle = s
            button.image = nil
        } else if model.breakEnded {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.orange,
                .font: NSFont.systemFont(ofSize: 11, weight: .medium)
            ]
            button.attributedTitle = NSAttributedString(string: "● ▶", attributes: attrs)
            button.image = nil
        } else {
            button.attributedTitle = NSAttributedString()
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
        }
    }

    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    // MARK: Analytics window

    private func openAnalytics() {
        popover.performClose(nil)
        if analyticsWindow == nil {
            let view = AnalyticsView(store: model.store,
                                     onClose: { [weak self] in self?.analyticsWindow?.close() })
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 540),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Analytics"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: view)
            window.center()
            analyticsWindow = window
        }
        analyticsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Model observation

    private func observeModel() {
        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateButton() }
            }
            .store(in: &cancellables)

        model.$breakEnded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] breakEnded in
                if breakEnded { self?.showPopover() }
            }
            .store(in: &cancellables)
    }

    // MARK: Notifications

    private func setupNotifications() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let startAction = UNNotificationAction(
            identifier: "START_SESSION",
            title: "Start Session",
            options: [.foreground]
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: "BREAK_END",
                actions: [startAction],
                intentIdentifiers: [],
                options: []
            )
        ])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "START_SESSION" {
            DispatchQueue.main.async { self.model.start() }
        }
        completionHandler()
    }
}
