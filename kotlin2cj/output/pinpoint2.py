#!/usr/bin/env python3
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

def test_code(code, label):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(code)
        tmp = f.name
    try:
        out = '/tmp/pin2.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        preview = "(empty)" if size < 5 else open(out).read(200)
        print(f"  [{label}] size={size}B: {preview[:150]}", flush=True)
        if r.stderr: print(f"    stderr: {r.stderr[:200]}", flush=True)
        return size
    finally:
        os.unlink(tmp)

# Base: first 50 lines of Element.kt (works)
with open("/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt") as f:
    lines = f.readlines()

header = "".join(lines[:50])

# Test 1: header + lock field
test_code(header + '    private val lock = Synchronizable()\n}\n', "header + lock")

# Test 2: header + @JsName annotation + var
test_code(header + '''
    @Suppress("unused")
    var tag = ""
}
''', "header + @Annotation + var")

# Test 3: header + var with newline to annotation
test_code(header + '''
    @Suppress("unused")
    var tag = ""
        protected set
}
''', "header + var with protected set")

# Test 4: header + lock + @JsName var
test_code(header + '''
    private val lock = Synchronizable()
    @Suppress("unused")
    var tag = ""
}
''', "header + lock + annotation var")

# Test 5: just the problematic lines 50-60
code_50_60 = ''.join(lines[50:60])
test_code(header + code_50_60 + '}\n', "header + lines 50-60")

# Test 6: line by line
for i in range(50, 61):
    code = header + ''.join(lines[50:i+1]) + '}\n'
    test_code(code, f"header + lines 50-{i}")
