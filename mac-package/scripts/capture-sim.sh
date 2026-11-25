#!/usr/bin/env bash
# One clean screenshot of the app in a simulator.
#   capture-sim.sh "<device name or UDID>" <shot-name> <output-dir> [app launch arguments...]
# 9:41 clock, full battery and signal, dark appearance. Run build-ios.sh first.
set -euo pipefail
DEVICE="$1"; NAME="$2"; OUT="$3"; shift 3
DERIVED="${DERIVED:-/tmp/stillscope-derived}"
APP="$(find "$DERIVED/Build/Products" -name 'Desqueeze.app' -path '*iphonesimulator*' | head -1)"
[ -n "$APP" ] || { echo "No simulator build found; run build-ios.sh first"; exit 1; }
# A UDID is taken as it is: two simulators on different iOS versions can share a name.
if [[ "$DEVICE" =~ ^[0-9A-F-]{36}$ ]]; then UDID="$DEVICE"; else
UDID="$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
fi
[ -n "$UDID" ] || { echo "No simulator named: $DEVICE"; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl ui "$UDID" appearance dark
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" com.chambersandlight.stillscope 2>/dev/null || true
xcrun simctl launch "$UDID" com.chambersandlight.stillscope "$@" >/dev/null
sleep "${SETTLE:-10}"
mkdir -p "$OUT"
xcrun simctl io "$UDID" screenshot "$OUT/$NAME.png"
echo "$OUT/$NAME.png"
