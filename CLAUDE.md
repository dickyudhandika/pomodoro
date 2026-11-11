# Pomodoro macOS App

## Project Overview
macOS menu-bar-only Pomodoro timer. The whole UI is a slim, task-first popover (task title + round start/pause button, with a task dropdown). The only window is Analytics. No external dependencies — pure Swift, SwiftUI, and system frameworks.

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
  - Phase cycling, session completion, task-segment logging
  - Dispatches notifications

SessionStore (ObservableObject)
  - Stores completed sessions in UserDefaults (key: "pomodoro.sessions")
  - Analytics helpers: todaySessions, todayFocusMinutes, etc.

TaskStore (ObservableObject)
  - Two-level task list (tasks + subtasks) and current selection
  - UserDefaults keys: "pomodoro.tasks", "pomodoro.selectedTask"

AppDelegate (NSApplicationDelegate)
  - Owns TimerModel + TaskStore
  - NSStatusItem + attributed string button in menu bar
  - NSPopover (transient, animates = false) hosting MenuBarView
  - Lazily created NSWindow hosting AnalyticsView
  - UNUserNotificationCenter setup and delegate
  - Combine subscribers to react to model changes

Views (SwiftUI)
  - MenuBarView     — popover (280px wide): slim row + task dropdown + footer
  - AnalyticsView   — session history by day (own window, onClose closure)
```

## Key Files

| File | Purpose |
|------|---------|
| `Sources/Pomodoro/TimerModel.swift` | Timer state, phase logic, session recording |
| `Sources/Pomodoro/Session.swift` | Session model + UserDefaults persistence + analytics |
| `Sources/Pomodoro/Tasks.swift` | `TaskItem` + `TaskStore` (tasks, subtasks, selection, persistence) |
| `Sources/Pomodoro/PomodoroApp.swift` | App entry point, AppDelegate, menu bar, popover, analytics window |
| `Sources/Pomodoro/Theme.swift` | `ShadTheme` design tokens, `Color(hex:)`, `Phase.accent` |
| `Sources/Pomodoro/MenuBarView.swift` | Menu bar popover UI (task row, dropdown, footer) |
| `Sources/Pomodoro/AnalyticsView.swift` | Session history and daily stats (analytics window) |

## Key Patterns

### Timer Mechanics
- `Timer.publish(every: 0.5, on: .main, in: .common)` + Combine sink
- Elapsed time tracked via system `Date()` (drift-resistant, not frame count)
- Countdown = `remainingAtStart - (now - startDate)`; both are stored properties, reset on each start/resume
- Task segments are measured with a separate marker, `segmentStartRemaining` (segment = marker − remaining now), so switching tasks never touches `startDate` or the countdown

### Phase Cycling
```
Work (25m) → Short Break (5m)  [after pomodoros 1, 2, 3]
Work (25m) → Long Break (15m)  [after every 4th pomodoro]
```
- Breaks start automatically when a focus phase completes; focus never auto-starts after a break (orange ▶ indicator, popover pops up, "Start Session" notification).
- No manual phase switching.

### Tasks & Popover Flow
- Popover = one slim row: task title (or "Select a task"; "Short Break"/"Long Break" during breaks) + round phase-coloured play/pause button (`model.toggle()`).
- Tapping the row body toggles the dropdown (`@State expanded`): tasks, indented subtasks, `+` (add subtask) and `×` (remove) on hover, "Add task…" field at the bottom. Footer: **Stop** (focus in progress) or **Skip break** (break), plus analytics, sound and quit icons.
- No animation anywhere: no `withAnimation`, `.animation` or transitions; popover `animates = false`; hosting controller `sizingOptions = .preferredContentSize` for instant resize.
- **Pick a task** → `TaskStore.select(id:)` + `TimerModel.selectTask(name:)`: during focus, logs the segment so far (≥5s) to the previous task and keeps the countdown running for the new one.
- Recorded task name (`TaskStore.selectedName`): `"Title"` or `"Parent › Sub"`. Empty name shows as "—" in analytics.
- Removing a parent removes its subtasks; removing the selected task clears the selection (segment logged to it).
- **Stop** (`TimerModel.stop()`): logs the current segment, then `reset()` to 25:00.
- `Session.countsAsPomodoro`: `true` only for a fully completed focus phase; task-switch and Stop segments are `false`; old records are `nil` (counted as before). `todayPomodoros` uses it.

### Persistence
- Sessions: `UserDefaults` key `"pomodoro.sessions"`, JSON-encoded via `Codable`
- Tasks: `UserDefaults` keys `"pomodoro.tasks"` (JSON `[TaskItem]`) and `"pomodoro.selectedTask"` (UUID string)
- Settings: `@AppStorage("soundEnabled")` for sound toggle

### UI Design System
- `ShadTheme` struct in `Theme.swift` — shadcn-inspired design tokens
- Hex-based `Color` initializer
- Phase accent colors: Red `#E84C3D` (work), Green `#40B87C` (short break), Blue `#4080EB` (long break)
- Dark/light themes defined in `ShadTheme`, toggled via `@Environment(\.colorScheme)`

### Menu Bar
- `LSUIElement = true` in Info.plist — no dock icon
- App is menu-bar-only: the SwiftUI scene is `Settings { EmptyView() }`
- Colored dot + "MM:SS" in status bar whenever a phase is in progress (dimmed when paused); ▶ indicator when break ends; timer icon when idle
- Popover is transient (closes on outside click)

### Notifications
- `UNNotificationRequest` with `nil` trigger (immediate)
- `"BREAK_END"` category with `"START_SESSION"` action for interactive notifications
- System "Funk" sound on phase completion
