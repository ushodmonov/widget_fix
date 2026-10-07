#!/bin/bash
# Puts the seeded UI bugs back and runs Tally on the simulator under flutter run, with the pid file
# Claude signals to hot reload: run before each take. DEVICE names the simulator or device to use
# (iPhone 18 Pro when not set); anything `flutter devices` lists works.
set -euo pipefail
cd "$(dirname "$0")/../tally"

DEVICE=${DEVICE:-iPhone 18 Pro}

git checkout demo-start -- lib
rm -rf .widget_fix/reports
mkdir -p .widget_fix

# An iOS simulator by name: boot it and show it. Xcode 27 shows simulators in Device Hub.
UDID=$(xcrun simctl list devices available 2>/dev/null | grep -m1 "$DEVICE (" | grep -oE '[0-9A-F-]{36}' || true)
if [ -n "$UDID" ]; then
  xcrun simctl boot "$UDID" 2>/dev/null || true
  open -ga DeviceHub 2>/dev/null || open -ga Simulator 2>/dev/null || true
  DEVICE=$UDID
fi

exec flutter run -d "$DEVICE" --pid-file .widget_fix/flutter.pid
