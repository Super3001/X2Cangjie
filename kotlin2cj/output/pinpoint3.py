#!/usr/bin/env python3
"""Test specific blank line behavior."""
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

def test_code(code, label):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(code)
        tmp = f.name
    try:
        out = '/tmp/pin3.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        preview = "(empty)" if size < 5 else open(out).read(300)
        print(f"  [{label}] size={size}B: {preview[:200]}", flush=True)
        if r.stderr: print(f"    stderr: {r.stderr[:200]}", flush=True)
        return size
    finally:
        os.unlink(tmp)

# Reproduce the blank line issue precisely
header = """package com.fleeksoft.ksoup.nodes

open class Node {
}
interface Iterable<T> {
}

/**
 * Doc
 */
open class Element : Node, Iterable<Element> {
"""

# Test: lock + blank line + more
test_code(header + '    private val lock = Synchronizable()\n\n    var tag = ""\n}\n', "lock+blank+var")
test_code(header + '    private val lock = Synchronizable()\n    var tag = ""\n}\n', "lock+var (no blank)")
test_code(header + '    private val lock = Synchronizable()\n\n}\n', "lock+blank+close")
test_code(header + '    private val lock = Synchronizable()\n}\n', "lock+close")

# Test: what about comments on blank-like lines?
test_code(header + '    private val lock = Synchronizable()\n    // comment\n    var tag = ""\n}\n', "lock+comment+var")
