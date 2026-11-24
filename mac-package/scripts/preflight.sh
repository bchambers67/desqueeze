#!/usr/bin/env bash
# Checks the Mac has what the package needs, and says what is missing.
set -u
ok=1
need() { if command -v "$1" >/dev/null 2>&1; then echo "  ok   $1"; else echo "  MISSING $1  ($2)"; ok=0; fi; }
echo "Tools"
need xcodebuild "install Xcode and open it once"
need xcrun "xcode-select --install"
need git "xcode-select --install"
need gh "brew install gh, then gh auth login"
need python3 "brew install python"
need swift "comes with Xcode"
need fastlane "brew install fastlane   (only needed for the upload phase)"
echo; echo "Xcode"; xcodebuild -version 2>/dev/null | head -2
echo; echo "Simulators (need an iPhone 6.9-inch, an iPad 13-inch, and any iPhone Duo)"
xcrun simctl list devices available 2>/dev/null | grep -Ei "iPhone .*(Pro Max|Duo)|iPad Pro 13" | sed 's/^ */  /' | head -12
echo; echo "Pillow (for the screenshot composer)"
python3 -c "import PIL; print('  ok   Pillow', PIL.__version__)" 2>/dev/null || { echo "  MISSING Pillow  (python3 -m pip install --user pillow)"; ok=0; }
echo; echo "App Store Connect API key (only needed for upload)"
for v in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
  if [ -n "${!v:-}" ]; then echo "  ok   $v is set"; else echo "  not set  $v"; fi
done
[ -n "${ASC_KEY_PATH:-}" ] && [ ! -f "$ASC_KEY_PATH" ] && echo "  ASC_KEY_PATH does not point at a file"
echo; [ $ok = 1 ] && echo "Preflight passed." || echo "Fix the MISSING items above, then run again."
