#!/usr/bin/env python3
"""Writes fastlane metadata from store/listing/ios.md and checks Apple's limits.

    python3 make-metadata.py     # writes fastlane/metadata/en-US/*.txt
Exits non-zero if a field is missing or over its limit.
"""
import re, sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
md = (root / "store/listing/ios.md").read_text()
out = root / "mac-package/fastlane/metadata/en-US"
out.mkdir(parents=True, exist_ok=True)

def row(field):
    m = re.search(rf"^\| {re.escape(field)} \| (.+?) \|", md, re.M)
    return m.group(1).strip() if m else None

def section(title, stop):
    m = re.search(rf"^## {re.escape(title)}\n+(.*?)(?=^## {re.escape(stop)})", md, re.M | re.S)
    return m.group(1).strip() if m else None

fields = {
    "name.txt": (row("App name"), 30),
    "subtitle.txt": (row("Subtitle"), 30),
    "promotional_text.txt": (row("Promotional text"), 170),
    "keywords.txt": (row("Keywords"), 100),
    "description.txt": (section("Description", "What's new (1.0)"), 4000),
    "release_notes.txt": (section("What's new (1.0)", "Review notes (for App Review)"), 4000),
}
bad = 0
for name, (text, limit) in fields.items():
    if not text:
        print("MISSING", name); bad = 1; continue
    (out / name).write_text(text + "\n")
    over = len(text) > limit
    bad |= over
    print(f"{name:24} {len(text):5}/{limit}{'  OVER LIMIT' if over else ''}")
print("written to", out)
sys.exit(bad)
