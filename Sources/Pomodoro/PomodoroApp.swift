import SwiftUI
import AppKit
import UserNotifications

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = TimerModel()

    var body: some Scene {
        // Main window
        WindowGroup(id: "main") {
            ContentView(model: model)
                .frame(minWidth: 360, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // Menu bar
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

// Dynamic menu bar label — shows countdown while running, icon when idle
struct MenuBarLabel: View {
    @ObservedObject var model: TimerModel

    var body: some View {
        if model.isRunning {
            HStack(spacing: 3) {
                Circle()
                    .fill(model.phase.accent)
                    .frame(width: 5, height: 5)
                Text(model.timeString)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        } else {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .medium))
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        NSApplication.shared.windows.first?.center()
    }

    // Keep alive in menu bar when main window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
