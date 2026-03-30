#!/bin/zsh
set -e

xcodebuild -project Pomodoro.xcodeproj \
           -target Pomodoro \
           -configuration Debug \
           CONFIGURATION_BUILD_DIR=.build/app \
           build 2>&1 | grep -E "error:|warning:|Build (succeeded|FAILED)"

open .build/app/Pomodoro.app
