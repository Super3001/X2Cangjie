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
        out = '/tmp/pin9.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        preview = "(empty)" if size < 10 else open(out).read(500)
        status = "OK" if size > 10 else "FAIL"
        print(f"  [{label}] {status} size={size}B: {preview[:300]}", flush=True)
    finally:
        os.unlink(tmp)

# Test: internal var + blank + KDoc + constructor
test_code(header + '''    var tag: String = ""
    internal var attributes: String? = null

    /**
     * KDoc comment
     */
    constructor(t: String) {
        this.tag = t
    }
}
''', "internal var + KDoc + ctor")

# Test: internal var + KDoc + constructor (no blank line)
test_code(header + '''    var tag: String = ""
    internal var attributes: String? = null
    /**
     * KDoc comment
     */
    constructor(t: String) {
        this.tag = t
    }
}
''', "internal var + KDoc + ctor (no blank before KDoc)")

# Test: the exact lines 62-77
body_62_77 = "".join(lines[62:77])
test_code(header + body_62_77 + '\n}\n', "exact lines 62-77")

# Test: lines 50-62 + lines 64-77 (skip blank line 63)
body_50_62 = "".join(lines[50:62])
body_64_77 = "".join(lines[64:77])
test_code(header + body_50_62 + body_64_77 + '\n}\n', "lines 50-62 + lines 64-77 (skip blank)")

# Test: lines 50-62 + lines 63-77 (include blank line 63)
body_63_77 = "".join(lines[63:77])
test_code(header + body_50_62 + body_63_77 + '\n}\n', "lines 50-62 + lines 63-77 (include blank)")
