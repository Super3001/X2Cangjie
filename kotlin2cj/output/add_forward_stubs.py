#!/usr/bin/env python3
STUBS = """
open class OutputSettings {
    func escapeMode(): Any { return None }
    func charset(): Charset { return Charset() }
    func charset(c: Charset): Unit {}
    func syntax(): Any { return None }
    func prettyPrint(): Bool { return false }
    func outline(): Bool { return false }
    func indentAmount(): Int64 { return 0 }
    func maxPaddingWidth(): Int64 { return 0 }
    func clone(): OutputSettings { return OutputSettings() }
}
open class Regex {
    init(pattern: String) {}
    func matches(input: String): Bool { return false }
    func replace(input: String, replacement: String): String { return "" }
}
interface Entry<K, V> { func getKey(): K; func getValue(): V }
"""
with open("/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src/_stubs.cj", "a") as f:
    f.write(STUBS)
print("Added OutputSettings/Regex/Entry forward declarations")
