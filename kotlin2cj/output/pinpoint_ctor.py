#!/usr/bin/env python3
"""Test which constructor pattern fails."""
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

def test_code(code, label):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
        f.write(code)
        tmp = f.name
    try:
        out = '/tmp/pin6.cj'
        r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
        size = os.path.getsize(out) if os.path.exists(out) else 0
        preview = "(empty)" if size < 10 else open(out).read(300)
        status = "OK" if size > 10 else "FAIL"
        print(f"  [{label}] {status} size={size}B: {preview[:250]}", flush=True)
        if r.stderr and 'SOC' not in r.stderr:
            print(f"    stderr: {r.stderr[:300]}", flush=True)
    finally:
        os.unlink(tmp)

pkg = "package test\n"

# Test 1: class with primary constructor (parenthesized params after class name)
test_code(pkg + """class Foo(a: String, b: Int) {
    var x = a
    var y = b
}
""", "primary ctor (class params)")

# Test 2: class with init block
test_code(pkg + """class Foo {
    var tag = ""
    init {
        this.tag = "hello"
    }
}
""", "init block")

# Test 3: class with secondary constructor
test_code(pkg + """class Foo {
    var tag = ""
    constructor(t: String) {
        this.tag = t
    }
}
""", "secondary ctor (constructor keyword)")

# Test 4: secondary constructor with delegation
test_code(pkg + """open class Foo(tag: String) {
    var tag: String = tag
    constructor(t: String, extra: Int) : this(t) {
        this.tag = t
    }
}
""", "secondary ctor with :this delegation")

# Test 5: annotation before constructor
test_code(pkg + """class Foo {
    var tag = ""
    @Suppress("unused")
    constructor(t: String) {
        this.tag = t
    }
}
""", "@Annotation + secondary ctor")

# Test 6: real Element.kt constructor syntax
test_code(pkg + """open class Node
open class Tag {
    companion object {
        fun valueOf(s: String, ns: String, ps: Any): Tag = Tag()
    }
}
open class Element(tag: Tag, baseUri: String?, attrs: Any?) : Node() {
    @Suppress("unused")
    constructor(tag: String, namespace: String) : this(
        Tag.valueOf(tag, namespace, "preserveCase"),
        null
    )
}
""", "Element-like secondary ctor")
