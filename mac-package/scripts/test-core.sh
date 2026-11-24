#!/usr/bin/env bash
# Runs the pure-Swift core tests.
set -euo pipefail
cd "$(dirname "$0")/../../DesqueezeiOS/DesqueezeCore"
swift test
