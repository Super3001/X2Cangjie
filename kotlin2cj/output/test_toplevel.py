#!/usr/bin/env python3
"""Test parse_top_level with Element.kt class signature specifically."""
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

# Test: the exact class signature from Element.kt
code = """package com.fleeksoft.ksoup.nodes

import com.fleeksoft.ksoup.KmpJsExport

open class Node {
}
interface Iterable<T> {
}

/**
 * Doc
 */
@KmpJsExport
public open class Element : Node, Iterable<Element> {
    var tag = ""
}
"""

with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
    f.write(code)
    tmp = f.name

out = '/tmp/ttest.cj'
r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
print(f"STDERR: {r.stderr}")
print(f"Output size: {os.path.getsize(out)}")
with open(out) as fh:
    c = fh.read()
    if len(c) < 1000:
        print(f"FULL: {c}")
    else:
        print(f"First 500: {c[:500]}")
os.unlink(tmp)
