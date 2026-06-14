#!/usr/bin/env python3
"""Fix remaining let it = _also_it patterns."""
import os, re

SRC = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src"

for fname in os.listdir(SRC):
    if not fname.endswith(".cj"):
        continue
    fpath = os.path.join(SRC, fname)
    with open(fpath) as f:
        content = f.read()

    if 'let it = _also_it' not in content:
        continue

    # Pattern 1: { it => ... let it = _also_it ... return _also_it }()
    # Fix: remove it param, use _also_it directly, remove let it line
    content = re.sub(
        r'\{ it =>\s*\n(\s+)let _also_it = ([^\n]+)\n\s+let it = _also_it\n',
        r'{ =>\n\1let _also_it = \2\n',
        content
    )
    # Pattern 2: { => ... let it = _also_it ... }() — no lambda param conflict
    # Just remove the let it line (it's a no-op shadow)
    content = re.sub(r'\n\s+let it = _also_it\n', '\n', content)

    # Pattern 3: while ({ it => ... let it = _also_it })
    content = re.sub(
        r'while \(\{ it =>\s*\n(\s+)let _also_it = ([^\n]+)\n\s+let it = _also_it\n',
        r'while ({ =>\n\1let _also_it = \2\n',
        content
    )

    with open(fpath, 'w') as f:
        f.write(content)

    # Verify
    with open(fpath) as f:
        remaining = f.read()
    if 'let it = _also_it' in remaining:
        print(f"  WARNING: {fname} still has let it = _also_it (manual fix needed)")
    else:
        print(f"Fixed: {fname}")
