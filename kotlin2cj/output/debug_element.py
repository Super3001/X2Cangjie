#!/usr/bin/env python3
import subprocess
BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"
KT = "/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt"
OUT = "/tmp/element_test.cj"
r = subprocess.run([BIN, KT, "-o", OUT], capture_output=True, text=True, timeout=30)
print(f"Return code: {r.returncode}")
print(f"STDERR: {r.stderr[:500]}")
print(f"STDOUT: {r.stdout[:500]}")
with open(OUT) as f:
    content = f.read()
print(f"Output size: {len(content)} bytes")
print(f"First 200 chars: {content[:200]}")
print(f"Last 200 chars: {content[-200:]}")
