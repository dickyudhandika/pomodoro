# Pomodoro macOS

## Install (for normal users)
1. Download `Pomodoro-macOS-v0.1.0.dmg` (or `.zip`) from the latest GitHub Release.
2. Open it and drag `Pomodoro.app` into `Applications`.
3. Open Terminal and run:
   `xattr -dr com.apple.quarantine /Applications/Pomodoro.app`
4. Open `Applications` and double-click `Pomodoro.app`.

## Run from source (developer)
1. macOS 13+ only. Install Xcode or Xcode Command Line Tools (`xcodebuild` is required).
2. Clone the repo and run `./run.sh`.

## Build distributable bundle
1. `swift build -c release`
2. `ditto -c -k .build/app/Pomodoro.app Pomodoro-macOS-v0.1.0.zip`
