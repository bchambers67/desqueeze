#!/usr/bin/env bash
# A screenshot of the front window of an app on this Mac, without its shadow.
#   capture-mac.sh <app name> <shot-name> <output-dir>
set -euo pipefail
APPNAME="$1"; NAME="$2"; OUT="$3"
mkdir -p "$OUT"
osascript -e "tell application \"$APPNAME\" to activate"
sleep 1
screencapture -x -o -w "$OUT/$NAME.png"   # click the window when the cursor changes
echo "$OUT/$NAME.png"
