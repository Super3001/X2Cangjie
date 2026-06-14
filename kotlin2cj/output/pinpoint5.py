#!/usr/bin/env python3
"""Binary search within lines 50-100 of Element.kt body."""
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

with open("/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt") as f:
    lines = f.readlines()

header = "".join(lines[:49])  # Up to class opening

def test_code(code, label):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(code)
        tmp = f.name
    try:
        out = '/tmp/pin5.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        if size > 10:
            preview = open(out).read(400)
        else:
            preview = "(empty)"
        status = "OK" if size > 10 else "FAIL"
        print(f"  [{label}] {status} size={size}B: {preview[:250]}", flush=True)
        if r.stderr and 'SOC' not in r.stderr:
            print(f"    stderr: {r.stderr[:300]}", flush=True)
        return size
    finally:
        os.unlink(tmp)

# Binary search: find the exact line range that breaks parsing
# We know lines 0-50 work, lines 0-100 fail
# Let's narrow down

# Test: header + lines 50-70 (first 20 lines of body)
body_50_70 = "".join(lines[50:70])
test_code(header + body_50_70 + '}\n', "body lines 50-69")

# Test: header + lines 50-60
body_50_60 = "".join(lines[50:60])
test_code(header + body_50_60 + '}\n', "body lines 50-59")

# Test: header + lines 50-55
body_50_55 = "".join(lines[50:55])
test_code(header + body_50_55 + '}\n', "body lines 50-54")

# Test: individual problematic constructs
# Line 50-54: lock + blank + @JsName + var tag:Tag + protected set
test_code(header + '''    private val lock = Synchronizable()

    @JsName("_tag")
    var tag: Tag
        protected set
    private var _baseUri: String? = null
}
''', "lock+@JsName+protected set")

# What about constructor with default args?
test_code(header + '''    var tag: Tag = Tag("div")
    init() {
        this.tag = tag
    }
}
''', "simple init constructor")

# The actual constructors in Element.kt
test_code(header + "".join(lines[50:76]) + '\n}\n', "body through first constructor (line 76)")
