#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Pomodoro"
VERSION="v0.1.0"
APP_PATH=".build/app/${APP_NAME}.app"
STAGE_DIR=".build/dmg-stage"
RW_DMG=".build/${APP_NAME}-temp.dmg"
FINAL_DMG="${APP_NAME}-macOS-${VERSION}.dmg"
VOL_NAME="${APP_NAME}"

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found at $APP_PATH"
  echo "Build first: swift build -c release"
  exit 1
fi

rm -rf "$STAGE_DIR" "$RW_DMG" "$FINAL_DMG"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/"

hdiutil create -quiet -srcfolder "$STAGE_DIR" -volname "$VOL_NAME" -fs HFS+ -format UDRW "$RW_DMG"

MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")
DEVICE=$(echo "$MOUNT_OUTPUT" | awk '/^\/dev\// {print $1; exit}')
MOUNT_POINT="/Volumes/${VOL_NAME}"

# Add Applications shortcut directly inside DMG
ln -s /Applications "$MOUNT_POINT/Applications"

# Finder layout: app on left, Applications alias on right (drag-and-drop flow)
osascript <<APPLESCRIPT
  tell application "Finder"
    tell disk "${VOL_NAME}"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {120, 120, 740, 440}
      set theViewOptions to the icon view options of container window
      set arrangement of theViewOptions to not arranged
      set icon size of theViewOptions to 128
      try
        set position of item "${APP_NAME}.app" of container window to {170, 170}
      end try
      try
        set position of item "Applications" of container window to {450, 170}
      end try
      update without registering applications
      delay 1
      close
    end tell
  end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE" -quiet
hdiutil convert "$RW_DMG" -quiet -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"

rm -rf "$STAGE_DIR" "$RW_DMG"

echo "Created: $FINAL_DMG"