# Pomodoro for macOS

A native macOS menu bar Pomodoro timer focused on quick start/stop flow, task tracking, and clean analytics.

- Platform: macOS 13+
- Built with: SwiftUI + AppKit (no external dependencies)
- Primary UI: menu bar popover
- Secondary UI: main app window (analytics + full controls)

## What the app does

- Uses classic Pomodoro phases:
  - Focus: 25m
  - Short Break: 5m
  - Long Break: 15m (every 4th completed focus)
- Shows live timer in menu bar.
- Sends macOS notifications when a phase ends.
- Stores session history locally for daily analytics.
- Lets you stop/switch task tracking without resetting the running timer.

## How it works (user flow)

1. Start a focus session.
2. Timer counts down in the menu bar.
3. On completion, app automatically switches to break phase.
4. After break ends, app switches back to focus.
5. Analytics view shows focus time, pomodoro count, and task history.

## Controls

Main window:
- Start/Pause: starts or pauses current phase.
- Stop (when task is active): logs current task segment, clears task, timer keeps running.
- Reset (when no active task): resets current phase timer.
- Skip: finishes current phase immediately and advances.
- Phase tabs: manually switch Focus / Short Break / Long Break.
- Task input: set what you’re working on (locked while a task is actively tracked).
- Analytics button (chart icon): opens detailed stats and history.

Menu bar popover:
- Start/Pause
- Open main window
- Sound on/off toggle

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
- `Sources/Pomodoro/ContentView.swift` — main window UI
- `Sources/Pomodoro/MenuBarView.swift` — compact menu bar popover UI
- `Sources/Pomodoro/AnalyticsView.swift` — daily summary + history
- `Sources/Pomodoro/PomodoroApp.swift` — app entry + status bar + popover wiring
- `scripts/make_dmg.sh` — DMG builder with drag-to-Applications shortcut

## Roadmap (recommended)

- Add Apple Developer code signing + notarization to remove quarantine workaround.
- Add CI release pipeline to auto-build DMG/ZIP on tag.
