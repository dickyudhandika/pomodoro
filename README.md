# Pomodoro for macOS

A native macOS menu bar Pomodoro timer built around your task list: pick a task, press play, get to work.

- Platform: macOS 13+
- Built with: SwiftUI + AppKit (no external dependencies)
- UI: a slim menu bar popover (no main window) plus an Analytics window

## What the app does

- Uses classic Pomodoro phases:
  - Focus: 25m
  - Short Break: 5m
  - Long Break: 15m (every 4th completed focus)
- Keeps a list of tasks and subtasks to work on.
- Shows the live countdown in the menu bar (dimmed while paused).
- Starts breaks automatically when a focus session ends.
- Sends macOS notifications when a phase ends.
- Stores session history locally for daily analytics.
- Lets you switch tasks mid-session without resetting the timer.

## How it works (user flow)

1. Click the menu bar icon. The popover opens with your task list already showing, under a slim row with the current task and a round play button.
2. Tap a task (or subtask) to select it, or type a new one in "Add task…" and press Return (it gets selected for you).
3. Tap the round button to start. The countdown runs in the menu bar.
4. When focus ends, the break starts on its own.
5. When the break ends, the menu bar shows an orange ▶ and the popover opens; tap play (or "Start Session" on the notification) to focus again.
6. Analytics shows focus time, pomodoro count and task history.

## Controls

Slim row:
- Task title: tap to hide or show the task list (it is shown every time you open the popover). Shows "Select a task" when nothing is selected, and "Short Break" / "Long Break" during breaks.
- Round button: start / pause.

Task list:
- Tap a task or subtask to select it. If a focus session is running, the time so far is logged to the previous task and the countdown keeps going for the new one.
- "Add task…": type and press Return. The new task is selected for you, unless a focus session is already running.
- Hover a task for `+` (add a subtask) and `×` (remove). Removing a task also removes its subtasks.
- Time on a subtask is logged as "Task › Subtask".

Footer (in the open task list):
- Stop (during focus): logs the time spent so far and resets the timer to 25:00.
- Skip break (during a break): ends the break.
- Analytics, sound on/off, quit.

## Install (recommended for normal users)

1. Download `Pomodoro-macOS-v0.1.0.dmg` from Releases.
2. Open the DMG.
3. Drag `Pomodoro.app` to `Applications`.
4. Open `Applications` and launch `Pomodoro.app`.

Release URL:
- https://github.com/dickyudhandika/pomodoro/releases

## If macOS blocks the app on first launch

Because this build is not notarized yet, Gatekeeper may block it.
Run once in Terminal:

`xattr -dr com.apple.quarantine /Applications/Pomodoro.app`

Then open the app again.

## Notes about GitHub release assets

GitHub always shows auto-generated source archives (`Source code (zip/tar.gz)`).
For end users, download only:
- `Pomodoro-macOS-v0.1.0.dmg` (best)
- or `Pomodoro-macOS-v0.1.0.zip`

## Run from source (developer)

Requirements:
- macOS 13+
- Xcode or Xcode Command Line Tools

Commands:
- `./run.sh` → build debug app and launch
- `swift build` → compile only

You can also open `Pomodoro.xcodeproj` in Xcode and run.

## Build distribution files

1. Build release app:
   `swift build -c release`

2. Build installer DMG with drag-to-Applications layout:
   `./scripts/make_dmg.sh`

3. Optional ZIP build:
   `ditto -c -k .build/app/Pomodoro.app Pomodoro-macOS-v0.1.0.zip`

## Project structure

- `Sources/Pomodoro/TimerModel.swift` — timer state, phase transitions, notifications
- `Sources/Pomodoro/Session.swift` — session model + local persistence + analytics helpers
- `Sources/Pomodoro/Tasks.swift` — tasks/subtasks, selection, local persistence
- `Sources/Pomodoro/MenuBarView.swift` — menu bar popover UI (task row, task list, footer)
- `Sources/Pomodoro/AnalyticsView.swift` — daily summary + history
- `Sources/Pomodoro/Theme.swift` — colours and design tokens
- `Sources/Pomodoro/PomodoroApp.swift` — app entry, status bar, popover and analytics window
- `scripts/make_dmg.sh` — DMG builder with drag-to-Applications shortcut

## Roadmap (recommended)

- Add Apple Developer code signing + notarization to remove quarantine workaround.
- Add CI release pipeline to auto-build DMG/ZIP on tag.
