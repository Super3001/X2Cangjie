#!/usr/bin/env python3
"""Test with actual header + various body constructs."""
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

with open("/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt") as f:
    lines = f.readlines()

header = "".join(lines[:49])  # Up to class open brace

def test_code(code, label):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(code)
        tmp = f.name
    try:
        out = '/tmp/pin7.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        preview = "(empty)" if size < 10 else open(out).read(400)
        status = "OK" if size > 10 else "FAIL"
        print(f"  [{label}] {status} size={size}B: {preview[:300]}", flush=True)
        if r.stderr and 'SOC' not in r.stderr:
            print(f"    stderr(first 300): {r.stderr[:300]}", flush=True)
        return size
    finally:
        os.unlink(tmp)

# Test: header + just the lock field was OK
# Test: header + lock + init block
test_code(header + '''    private val lock = Synchronizable()
    init {
        // nothing
    }
}
''', "lock + init block")

# Test: header + init with no preceding field
test_code(header + '''    init {
        // nothing
    }
}
''', "init only (no preceding field)")

# Test: header + field with type that requires import
test_code(header + '''    var tag: Tag = Tag("div")
}
''', "field with Tag constructor call")

# Test: header + simple field only (no constructor call)
test_code(header + '''    var tag: String = "div"
}
''', "field with String type")

# Test: header + lock + var tags (matching what Element.kt has)
test_code(header + "".join(lines[50:54]) + "}\n", "lock + @JsName + var tag + protected set")

# Test: header + lock + var tag + init
test_code(header + "".join(lines[50:54]) + '''
    init {
        this.tag = Tag("div")
    }
}
''', "lock + vars + init block")

# Test: Is it the 'constructor' keyword specifically?
test_code(header + '''    constructor() {}
}
''', "empty secondary ctor")

# What about the REAL lines 50-60?
# Let me print lines 50-60 for inspection
print("\n=== Lines 50-60 of Element.kt ===")
for i in range(49, 61):
    print(f"  {i+1}: {lines[i].rstrip()}")
