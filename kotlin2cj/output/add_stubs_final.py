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
open class Regex {
    init(pattern: String) {}
    func matches(input: String): Bool { return false }
    func replace(input: String, replacement: String): String { return "" }
}
interface Entry<K, V> { func getKey(): K; func getValue(): V }
open class ThreadLocal<T> {
    init(factory: () -> T) {}
    func get(): T { return factory() }
    func setValue(value: T): Unit {}
}
open class SoftPool<T> {
    init(factory: () -> T) {}
    func borrow(): T { return factory() }
    func release(obj: T): Unit {}
}
"""
with open("/home/songy/SunriseSummer-X2Cangjie/kotlin2cj/output/ksoup_cj/src/_stubs.cj", "a") as f:
    f.write(STUBS)
print("Added comprehensive stubs")
