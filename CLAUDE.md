# Pomodoro macOS App

## Project Overview
macOS menu bar Pomodoro timer. The menu bar is the primary UI; the main window is secondary/optional. No external dependencies — pure Swift, SwiftUI, and system frameworks.

- **Platform:** macOS 13+ (Ventura)
- **Language:** Swift 5.8+
- **Frameworks:** SwiftUI, AppKit, Combine, UserNotifications, Foundation
- **Bundle ID:** `com.thenom4design.Pomodoro`

## Build & Run

```bash
./run.sh          # build Debug + launch app
swift build       # SPM build only
```

Or open `Pomodoro.xcodeproj` in Xcode and run from there.

## Architecture

```
TimerModel (ObservableObject)
  - Core timer state and mechanics
  - Phase cycling, session completion
  - Dispatches notifications

SessionStore (ObservableObject)
  - Stores completed sessions in UserDefaults (key: "pomodoro.sessions")
  - Analytics helpers: todaySessions, todayFocusMinutes, etc.

AppDelegate (NSApplicationDelegate)
  - NSStatusItem + attributed string button in menu bar
  - NSPopover (transient) hosting MenuBarView
  - UNUserNotificationCenter setup and delegate
  - Combine subscribers to react to model changes

Views (SwiftUI)
  - ContentView     — main window (360×500), timer ring, phase tabs, task input
  - MenuBarView     — popover (240px wide), compact controls
  - AnalyticsView   — modal sheet, session history by day
```

## Key Files

| File | Purpose |
|------|---------|
| `Sources/Pomodoro/TimerModel.swift` | Timer state, phase logic, session recording |
| `Sources/Pomodoro/Session.swift` | Session model + UserDefaults persistence + analytics |
| `Sources/Pomodoro/PomodoroApp.swift` | App entry point, AppDelegate, menu bar setup |
| `Sources/Pomodoro/ContentView.swift` | Main window UI, `ShadTheme` design tokens |
| `Sources/Pomodoro/MenuBarView.swift` | Menu bar popover UI |
| `Sources/Pomodoro/AnalyticsView.swift` | Session history and daily stats sheet |

## Key Patterns

### Timer Mechanics
- `Timer.publish(every: 0.5, on: .main, in: .common)` + Combine sink
- Elapsed time tracked via system `Date()` (drift-resistant, not frame count)
- `startDate` + `elapsedBeforePause` handle pause/resume without losing time

### Phase Cycling
```
Work (25m) → Short Break (5m)  [after pomodoros 1, 2, 3]
Work (25m) → Long Break (15m)  [after every 4th pomodoro]
```

### Task Tracking & Stop Button
- **Stop task** (`TimerModel.stopTask()`): logs the current task to analytics with elapsed time, clears the task name, resets elapsed tracking — but the pomodoro timer keeps running uninterrupted. This lets users switch tasks mid-pomodoro without resetting the countdown.
- `hasActiveTask: Bool` — `true` when in work phase and either running with a task name or a session task name is locked in. Drives the Stop vs Reset button swap in `ContentView.controls`.
- Task input is disabled when `hasActiveTask` is true; editable otherwise (including while timer runs after a stop, so user can type the next task).
- Left control button: **stop.fill** (phase-colored) when `hasActiveTask`, **arrow.counterclockwise** (reset) otherwise.
- Auto-save on task rename: if the user renames the task during a paused work session and ≥60s have elapsed, the original task is auto-saved as a separate session (handled in `start()`).

### Persistence
- Sessions: `UserDefaults` key `"pomodoro.sessions"`, JSON-encoded via `Codable`
- Settings: `@AppStorage("soundEnabled")` for sound toggle

### UI Design System
- `ShadTheme` struct in `ContentView.swift` — shadcn-inspired design tokens
- Hex-based `Color` initializer
- Phase accent colors: Red `#E84C3D` (work), Green `#40B87C` (short break), Blue `#4080EB` (long break)
- Dark/light themes defined in `ShadTheme`, toggled via `@Environment(\.colorScheme)`

### Menu Bar
- `LSUIElement = true` in Info.plist — no dock icon
- Colored dot + "MM:SS" in status bar; ▶ indicator when break ends
- Popover is transient (closes on outside click)

### Notifications
- `UNNotificationRequest` with `nil` trigger (immediate)
- `"BREAK_END"` category with `"START_SESSION"` action for interactive notifications
- System "Funk" sound on phase completion
