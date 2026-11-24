#!/usr/bin/env bash
# Gathers what is needed to find what holds a lock when the Mac app is ended
# with 0xDEAD10CC. Run it right after a crash.
set -u
OUT="${1:-$HOME/Desktop/crash-bundle-$(date +%H%M%S).txt}"
{
  echo "== runningboardd / 10cc, last 20 minutes =="
  log show --last 20m --info --predicate 'eventMessage CONTAINS[c] "10cc" OR (process == "runningboardd" AND eventMessage CONTAINS[c] "stillscope")' 2>&1 | tail -200
  echo; echo "== newest crash reports for the app =="
  ls -t ~/Library/Logs/DiagnosticReports/Desqueeze* 2>/dev/null | head -3
  echo; echo "== files the app has open right now (if it is running) =="
  PID="$(pgrep -x Desqueeze | head -1)"
  if [ -n "$PID" ]; then lsof -p "$PID" 2>/dev/null | grep -Ev "\.dylib|\.framework|/System/|/usr/lib" | head -80; else echo "app not running"; fi
} > "$OUT" 2>&1
echo "$OUT"
