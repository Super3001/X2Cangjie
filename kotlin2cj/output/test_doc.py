#!/usr/bin/env python3
import subprocess, sys
BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"
KT = "/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Document.kt"
OUT = "/tmp/doc_test.cj"
r = subprocess.run([BIN, KT, "-o", OUT], capture_output=True, text=True)
print("STDERR:", r.stderr)
print("---OUTPUT(first 40 lines)---")
with open(OUT) as f:
    for i, line in enumerate(f):
        if i >= 40: break
        print(f"{i+1}: {line}", end="")
