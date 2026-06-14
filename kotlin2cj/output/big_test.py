#!/usr/bin/env python3
"""Test progressively larger prefixes of Element.kt to find failure threshold."""
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"
KT = "/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt"

with open(KT) as f:
    lines = f.readlines()

def test_prefix(end_line):
    code = "".join(lines[:end_line])
    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(code)
        tmp = f.name
    try:
        out = '/tmp/big_test.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=30)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        if r.stderr:
            err = r.stderr[:150].replace('\n', ' ')
        else:
            err = ""
        return size, err
    finally:
        os.unlink(tmp)

# Test progressively
for pct in [5, 10, 20, 30, 40, 50, 75, 100]:
    end = int(len(lines) * pct / 100)
    size, err = test_prefix(end)
    status = "OK" if size > 10 else "FAIL"
    print(f"  {pct}% (line {end}/{len(lines)}): {status} size={size}B err='{err}'"[:200])
