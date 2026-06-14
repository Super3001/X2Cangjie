#!/usr/bin/env python3
import subprocess, tempfile, os

BIN = "/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/target/release/kotlin2cj"

# Test small working file
code = """package test
class Foo {
    var x = 1
    fun bar(): Int { return x }
}
"""
with tempfile.NamedTemporaryFile(mode='w', suffix='.kt', delete=False, dir='/tmp') as f:
    f.write(code)
    tmp = f.name

out = '/tmp/small_test.cj'
r = subprocess.run([BIN, tmp, '-o', out], capture_output=True, text=True, timeout=15)
print(f"STDERR: {r.stderr}")
print(f"Output size: {os.path.getsize(out)}")
with open(out) as fh:
    print(f"Output: {fh.read()}")
os.unlink(tmp)
