#!/usr/bin/env python3
"""Find the exact Kotlin syntax that kills the Element.kt parser.
Strategy: wrap chunks of Element.kt in a simple valid class, find which chunk fails."""
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"
KT = "/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt"

with open(KT) as f:
    lines = f.readlines()

# Chunk the class body (lines 50 to end-1) into pieces and test each in a wrapper
body_lines = lines[49:]  # From "public open class Element..." to end

# Test: just the class signature + body (no imports, no package)
# Wrap with package + necessary type stubs
def test_in_wrapper(code, label):
    wrapper = """package com.fleeksoft.ksoup.nodes
open class Node
interface Iterable<T>
""" + code
    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(wrapper)
        tmp = f.name
    try:
        out = '/tmp/wrap.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=30)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        status = "OK" if size > 10 else "FAIL"
        preview = "(empty)" if size < 10 else open(out).read(400)
        print(f"  [{label}] {status} size={size}B", flush=True)
        if status == "FAIL" and r.stderr:
            print(f"    stderr: {r.stderr[:200]}", flush=True)
        return size
    finally:
        os.unlink(tmp)

# Test chunks of the class body
chunk_size = 100
for start in range(0, len(body_lines), chunk_size):
    end = min(start + chunk_size, len(body_lines))
    chunk = "".join(body_lines[start:end])
    # If it's the first chunk, include class opening; otherwise, wrap in class
    if start == 0:
        code = chunk  # Has class declaration
    else:
        code = "class _Wrapper {\n" + chunk + "\n}\n"

    size = test_in_wrapper(code, f"chunk {start}-{end} (lines {49+start}-{49+end})")
    if size <= 10:
        # Binary search within this chunk
        print(f"    FAILING CHUNK: lines {49+start}-{49+end}", flush=True)
        for sub_start in range(start, end, 10):
            sub_end = min(sub_start + 10, end)
            sub_chunk = "".join(body_lines[sub_start:sub_end])
            if sub_start == 0:
                code = sub_chunk
            else:
                code = "class _Wrapper {\n" + sub_chunk + "\n}\n"
            test_in_wrapper(code, f"  sub {49+sub_start}-{49+sub_end}")
