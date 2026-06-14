#!/usr/bin/env python3
"""Test with ACTUAL Element.kt header, adding minimal body."""
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

with open("/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt") as f:
    lines = f.readlines()

def test_code(code, label):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(code)
        tmp = f.name
    try:
        out = '/tmp/pin4.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        preview = "(empty)" if size < 5 else open(out).read(300)
        print(f"  [{label}] size={size}B: {preview[:200]}", flush=True)
        if r.stderr: print(f"    stderr: {r.stderr[:500]}", flush=True)
        return size
    finally:
        os.unlink(tmp)

# Actual lines 1-49 + simple closing
header = "".join(lines[:49])
test_code(header + '}\n', "original header + close")

# Actual lines 1-48 (without KDoc)
header48 = "".join(lines[:48])
test_code(header48 + '\n}\n', "original header (no KDoc) + close")

# Lines 1-47 (without @KmpJsExport)
header47 = "".join(lines[:47])
test_code(header47 + '\n}\n', "lines 1-47 + close")

# Lines 1-46 (without blank line)
header46 = "".join(lines[:46])
test_code(header46 + '\n}\n', "lines 1-46 + close")

# Just the class sig (line 48) with different headers
# Test with minimal imports
minimal = """package com.fleeksoft.ksoup.nodes
import com.fleeksoft.ksoup.KmpJsExport
open class Node
interface Iterable<T>
@KmpJsExport
open class Element : Node, Iterable<Element> {
}
"""
test_code(minimal, "@KmpJsExport minimal")

# What about the specific import com.fleeksoft.ksoup.KmpJsExport?
with_import = """package com.fleeksoft.ksoup.nodes
import com.fleeksoft.ksoup.KmpJsExport
open class Node
interface Iterable<T>

@KmpJsExport
open class Element : Node, Iterable<Element> {
    var tag = ""
}
"""
test_code(with_import, "with KmpJsExport import")

# Test with actual import lines but simple class body
imports = "".join(lines[:40])  # Lines 1-40 (package + all imports)
test_code(imports + '@KmpJsExport\nopen class Element : Node, Iterable<Element> {\n    var tag = ""\n}\n', "actual imports + simple class")
