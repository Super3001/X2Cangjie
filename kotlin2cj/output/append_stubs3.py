#!/usr/bin/env python3
STUBS = """
class IntArray {
    init(size: Int64) {}
    var size: Int64 = 0
    operator func [](i: Int64): Int64 { return 0 }
    operator func []=(i: Int64, v: Int64): Unit {}
}
"""
with open("/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src/_stubs.cj", "a") as f:
    f.write(STUBS)
print("Added IntArray stub")
