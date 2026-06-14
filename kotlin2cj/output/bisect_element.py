#!/usr/bin/env python3
"""Bisect Element.kt to find which part causes parse failure."""
import subprocess, os, tempfile

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"
KT = "/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt"

with open(KT) as f:
    lines = f.readlines()

print(f"Total lines: {len(lines)}")

# Test progressively larger prefixes
def test_prefix(n_lines):
    """Test first n_lines of the file. Returns output size."""
    prefix = "".join(lines[:n_lines])
    # Must have valid package + at least one complete declaration
    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(prefix)
        tmp = f.name
    try:
        out = '/tmp/elem_bisect.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=30)
        if os.path.exists(out):
            size = os.path.getsize(out)
            # Show first 100 chars
            with open(out) as fh:
                content = fh.read(200)
            return size, content[:100], r.stderr[:200]
        return 0, "", r.stderr[:200]
    finally:
        os.unlink(tmp)

# Binary search for the failure point
good = 0
bad = len(lines)

# First find a working prefix (just package + imports + small decl)
for test_lines in [50, 100, 200, 500, 1000, 2000, 5000]:
    size, preview, err = test_prefix(test_lines)
    print(f"  Lines 0..{test_lines}: output={size}B, preview='{preview[:80]}', err='{err[:80]}'")

# Test the whole file minus some lines
for test_lines in [len(lines) - 1000, len(lines) - 100, len(lines) - 10, len(lines)]:
    size, preview, err = test_prefix(test_lines)
    print(f"  Lines 0..{test_lines}: output={size}B, preview='{preview[:80]}', err='{err[:80]}'")

# Test the LAST 1000 lines
suffix = "".join(lines[-1000:])
# Need a valid package header
full = "package com.fleeksoft.ksoup.nodes\n" + suffix
with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
    f.write(full)
    tmp = f.name
try:
    out = '/tmp/elem_suffix.cj'
    r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=30)
    if os.path.exists(out):
        size = os.path.getsize(out)
        print(f"  Last 1000 lines: output={size}B")
        with open(out) as fh:
            print(f"  Preview: {fh.read(200)}")
finally:
    os.unlink(tmp)
