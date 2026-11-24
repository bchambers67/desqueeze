#!/usr/bin/env bash
# Compiles the iOS app for the simulator: the compile check that has only ever
# been done by Xcode Cloud. Prints errors and deprecation warnings.
set -euo pipefail
cd "$(dirname "$0")/../../DesqueezeiOS"
python3 -I generate_project.py "$PWD" >/dev/null
xcodebuild -project Desqueeze.xcodeproj -scheme Desqueeze \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  -derivedDataPath "${DERIVED:-/tmp/stillscope-derived}" \
  CODE_SIGNING_ALLOWED=NO build > /tmp/stillscope-build.log 2>&1 || true
grep -E "error:|warning: .*deprecated" /tmp/stillscope-build.log | sort -u || true
if grep -q "BUILD SUCCEEDED" /tmp/stillscope-build.log; then echo "iOS build succeeded"; else echo "iOS build FAILED; log: /tmp/stillscope-build.log"; exit 1; fi
