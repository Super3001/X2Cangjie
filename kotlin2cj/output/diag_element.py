#!/usr/bin/env python3
"""Diagnose why Element.kt produces empty output."""
import subprocess, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"
KT = "/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt"
OUT = "/tmp/elem_diag.cj"

# Check file size
print(f"Source size: {os.path.getsize(KT)} bytes")

# Run with timeout, capture ALL output
try:
    r = subprocess.run([BIN, KT, "-o", OUT], capture_output=True, text=True, timeout=60)
    print(f"Return code: {r.returncode}")
    print(f"STDERR ({len(r.stderr)} chars):")
    print(r.stderr[:2000])
    print(f"---END STDERR---")
    print(f"STDOUT ({len(r.stdout)} chars):")
    print(r.stdout[:2000])
except subprocess.TimeoutExpired:
    print("TIMEOUT: translation took >60s")
    import sys; sys.exit(1)

# Check output
if os.path.exists(OUT):
    size = os.path.getsize(OUT)
    print(f"Output size: {size} bytes")
    with open(OUT) as f:
        content = f.read()
    if len(content) < 500:
        print(f"FULL OUTPUT: {repr(content)}")
    else:
        print(f"First 500: {content[:500]}")
        print(f"Last 500: {content[-500:]}")
else:
    print("Output file not created!")
