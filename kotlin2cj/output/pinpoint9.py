#!/usr/bin/env python3
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

with open("/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt") as f:
    lines = f.readlines()

header = "".join(lines[:49])

def test_code(code, label):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(code)
        tmp = f.name
    try:
        out = '/tmp/pinA.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        preview = "(empty)" if size < 10 else open(out).read(500)
        status = "OK" if size > 10 else "FAIL"
        print(f"  [{label}] {status} size={size}B", flush=True)
        print(f"    {preview[:200]}", flush=True)
        if r.stderr: print(f"    stderr: {r.stderr[:300]}", flush=True)
        return size
    finally:
        os.unlink(tmp)

# Reproduce: body 50-62 + blank 63 + close
body_50_62 = "".join(lines[50:62])
body_50_63 = "".join(lines[50:63])  # Includes blank line 63

test_code(header + body_50_62 + '}\n', "50-62 + close")
test_code(header + body_50_63 + '}\n', "50-63 + close")
test_code(header + body_50_62 + '\n}\n', "50-62 + blank + close")

# Maybe it's the trailing space/windows line ending on the blank line?
# Check content of line 63
print(f"\nLine 63 repr: {repr(lines[62])}")  # 0-indexed
print(f"Line 63 hex: {lines[62].encode().hex()}")
