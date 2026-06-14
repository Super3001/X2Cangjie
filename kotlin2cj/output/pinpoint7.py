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
        out = '/tmp/pin8.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        preview = "(empty)" if size < 10 else open(out).read(400)
        status = "OK" if size > 10 else "FAIL"
        print(f"  [{label}] {status} size={size}B: {preview[:300]}", flush=True)
    finally:
        os.unlink(tmp)

# Narrow down: lines 50-59 OK, lines 50-69 fail
# Test progressive additions
for end in [60, 61, 62, 63]:
    body = "".join(lines[50:end+1])
    test_code(header + body + '}\n', f"lines 50-{end}")

# Test specific constructs
test_code(header + '    internal var attributes: String? = null\n}\n', "internal var")
test_code(header + '    @Dot.Annotation\n    constructor() {}\n}\n', "dotted annotation + ctor")
test_code(header + '    @Dot.Annotation\n    var x = ""\n}\n', "dotted annotation + var")
