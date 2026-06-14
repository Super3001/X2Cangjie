#!/usr/bin/env python3
"""Pinpoint which Kotlin syntax in Element.kt causes parse failure."""
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

def test_code(code, label):
    """Test a Kotlin snippet. Returns (output_size, stderr)."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(code)
        tmp = f.name
    try:
        out = '/tmp/pinpoint.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        if size > 5:
            with open(out) as fh:
                preview = fh.read(200)
        else:
            preview = "(empty)"
        print(f"  [{label}] size={size}B: {preview[:120]}", flush=True)
        if r.stderr:
            print(f"    stderr: {r.stderr[:200]}", flush=True)
        return size
    finally:
        os.unlink(tmp)

# Test 1: simple class
test_code("""package test
class Element {
    var tag = ""
}
""", "simple class")

# Test 2: class with annotation
test_code("""package test
@Suppress("unused")
class Element {
    var tag = ""
}
""", "class+annotation")

# Test 3: class with multiple supertypes
test_code("""package test
open class Node
interface Iterable<T>
class Element : Node, Iterable<Element> {
    var tag = ""
}
""", "multiple supertypes")

# Test 4: property with protected set
test_code("""package test
class Element {
    var tag = ""
        protected set
    var childNodes = ""
}
""", "protected set")

# Test 5: KDoc + annotation + protected set combined
test_code("""package test
open class Node
interface Iterable<T>
/**
 * Doc comment
 */
@Suppress("unused")
open class Element : Node, Iterable<Element> {
    var tag = ""
        protected set
    var childNodes = ""
}
""", "combined")

# Test 6: Just the first 70 lines of Element.kt with simplified body
with open("/home/songy/ksoup/ksoup/src/com/fleeksoft/ksoup/nodes/Element.kt") as f:
    lines = f.readlines()

# Try lines 1-100 (package + imports + early class)
code100 = "".join(lines[:100])
code100 += "}\n"  # close the class
test_code(code100, "first 100 lines + close")

# Try lines 1-50 + simple class body
header = "".join(lines[:50])
minimal = header + "}\n"
test_code(minimal, "first 50 lines + close")

# Try just the class signature line
test_code("""package com.fleeksoft.ksoup.nodes
open class Node
interface Iterable<T>
open class Element : Node, Iterable<Element> {
    var lock = ""
}
""", "class sig minimal")

# Try with annotation on class
test_code("""package com.fleeksoft.ksoup.nodes
open class Node
interface Iterable<T>
@Suppress("unused")
open class Element : Node, Iterable<Element> {
    var lock = ""
}
""", "annotation + class sig")
