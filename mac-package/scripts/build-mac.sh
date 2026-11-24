#!/usr/bin/env bash
# Compiles the native macOS app (AnamorphicDesqueeze).
set -euo pipefail
cd "$(dirname "$0")/../.."
xcodebuild -project AnamorphicDesqueeze.xcodeproj -scheme AnamorphicDesqueeze \
  -destination 'platform=macOS' -configuration Debug \
  -derivedDataPath "${DERIVED_MAC:-/tmp/stillscope-derived-mac}" \
  CODE_SIGNING_ALLOWED=NO build > /tmp/stillscope-mac-build.log 2>&1 || true
grep -E "error:" /tmp/stillscope-mac-build.log | sort -u || true
if grep -q "BUILD SUCCEEDED" /tmp/stillscope-mac-build.log; then echo "Mac build succeeded"; else echo "Mac build FAILED; log: /tmp/stillscope-mac-build.log"; exit 1; fi
