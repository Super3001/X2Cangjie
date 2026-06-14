#!/usr/bin/env python3
"""Check if the engine produces any internal output for Element.kt."""
import subprocess, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"
KT = "/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt"
OUT = "/tmp/elem_dbg3.cj"

r = subprocess.run([BIN, KT, "-o", OUT], capture_output=True, text=True, timeout=60)
print(f"Return code: {r.returncode}")
print(f"STDOUT len: {len(r.stdout)}")
print(f"STDERR len: {len(r.stderr)}")

# Check for SOC messages on stderr
for line in r.stderr.split('\n'):
    if line.strip():
        print(f"  STDERR: {line[:200]}")

print(f"\nOutput file size: {os.path.getsize(OUT)}")
with open(OUT) as f:
    c = f.read()
    print(f"Output content: {repr(c[:500])}")

# Check if output has just a newline or actual content
print(f"\nOutput bytes: {c.encode()[:50]}")
