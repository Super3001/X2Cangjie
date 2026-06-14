#!/usr/bin/env python3
STUBS = """
open class Charset {
    func name(): String { return "" }
    func toString(): String { return "" }
}
class Charsets {
    static let UTF8 = Charset()
    static func forName(s: String): Charset { return Charset() }
}
class CharsetEncoder {
    init(cs: Charset) {}
    func encode(s: String): Any { return None }
    func flush(): Any { return None }
}
"""
with open("/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src/_stubs.cj", "a") as f:
    f.write(STUBS)
print("Appended Charset stubs")
