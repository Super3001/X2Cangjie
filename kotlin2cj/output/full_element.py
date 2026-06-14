#!/usr/bin/env python3
import subprocess, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"
KT = "/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt"
OUT = "/tmp/elem_full2.cj"

r = subprocess.run([BIN, KT, "-o", OUT], capture_output=True, text=True, timeout=60)
print(f"Return: {r.returncode}")
print(f"STDERR({len(r.stderr)}): {r.stderr[:500]}")
print(f"STDOUT({len(r.stdout)}): {r.stdout[:500]}")

size = os.path.getsize(OUT)
print(f"Output size: {size} bytes")
if size < 100:
    with open(OUT) as f:
        print(f"Content: {repr(f.read())}")
else:
    with open(OUT) as f:
        content = f.read()
        print(f"First 500: {content[:500]}")
        print(f"Last 500: {content[-500:]}")
        # Count lines
        lines = content.split('\n')
        print(f"Total lines: {len(lines)}")
        # Show class/function declarations
        import re
        for line in lines:
            m = re.match(r'^\s*(public\s+|private\s+|internal\s+|override\s+|static\s+)*(class|func|let|var|enum|interface|extend|init)\b', line)
            if m:
                print(f"  DECL: {line[:120]}")
