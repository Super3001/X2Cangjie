#!/usr/bin/env python3
"""Remove stale CamelCase .cj duplicates from ksoup output."""
import os, sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

removed = []
for f in sorted(os.listdir(SRC)):
    if f.endswith(".cj"):
        lower = f.lower()
        if f != lower and os.path.exists(os.path.join(SRC, lower)):
            # CamelCase version exists alongside snake_case — remove CamelCase
            full = os.path.join(SRC, f)
            os.remove(full)
            removed.append(f)

print(f"Removed {len(removed)} stale duplicates:")
for r in removed:
    print(f"  {r}")
print(f"Remaining: {len([f for f in os.listdir(SRC) if f.endswith('.cj')])} .cj files")
