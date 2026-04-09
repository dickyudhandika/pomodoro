# Pomodoro macOS

## Run from source
1. macOS 13+ only. Install Xcode or the Xcode Command Line Tools (the build relies on `xcodebuild`).
2. Clone the repo and run `./run.sh` — it builds the target and opens the menu bar app without opening Xcode.

## Build a distributable app bundle
1. `swift build -c release`
2. `ditto -c -k .build/apple/Products/Release/Pomodoro.app Pomodoro.zip`
3. Share `Pomodoro.zip` (users unzip, double-click `Pomodoro.app`). Attach the zip to a GitHub Release so people can download the app without building it themselves.
