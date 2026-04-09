import SwiftUI
import AppKit
import UserNotifications
import Combine

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(model: appDelegate.model)
                .frame(minWidth: 360, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let model = TimerModel()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()
    private var mainWindow: NSWindow?

    // MARK: Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        observeModel()
        setupNotifications()

        // Capture main window reference once it becomes key
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let win = note.object as? NSWindow, win.canBecomeMain {
                self?.mainWindow = win
            }
        }

        DispatchQueue.main.async {
            NSApplication.shared.windows.first?.center()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        updateButton()

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(model: model, openMainWindow: { [weak self] in self?.openMainWindow() })
        )
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }

        if model.isRunning {
            let dotAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: model.phase.accentNSColor,
                .font: NSFont.systemFont(ofSize: 8, weight: .medium)
            ]
            let timeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
            ]
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

    private func openMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
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
