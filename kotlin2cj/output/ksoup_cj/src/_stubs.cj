package ksoup_cj

import std.collection.*

interface AutoCloseable { func close(): Unit }
interface MutableIterator<T> { func hasNext(): Bool; func next(): T }
open class MutableMap<K, V> {
    public open func containsKey(key: K): Bool { return false }
    public open func containsValue(value: V): Bool { return false }
    public open func get(key: K): ?V { return None }
    public open func isEmpty(): Bool { return true }
    public open func clear(): Unit {}
    public open func put(key: K, value: V): ?V { return None }
    public open func putAll(from: HashMap<K, V>): Unit {}
    public open func remove(key: K): ?V { return None }
}
open class MutableEntry<K, V> {
    var key: K; var value: V
    init(k: K, v: V) { this.key = k; this.value = v }
    public open func setValue(newValue: V): V { return newValue }
}
interface Entry<K, V> { func getKey(): K; func getValue(): V }
open class MutableList {
    public open func add(element: Any): Bool { return true }
    public open func addAll(elements: Any): Bool { return true }
    public open func remove(element: Any): Bool { return false }
    public open func clear(): Unit {}; public open func isEmpty(): Bool { return true }
}
open class RuntimeException <: Exception { init() {}; init(msg: String) { super(msg) } }
interface Appendable {
    func append(csq: Any): Appendable
    func append(csq: Any, start: Int64, end: Int64): Appendable
    func append(c: Rune): Appendable
}
open class Regex {
    init(pattern: String) {}
    func matches(input: String): Bool { return false }
    func replace(input: String, replacement: String): String { return "" }
    func findAll(input: String): Any { return None }
}
open class Reader {
    init() {}
    func read(): Int64 { return -1 }
    func read(buf: Array<Rune>, off: Int64, len: Int64): Int64 { return -1 }
    func close(): Unit {}
}
open class IOException <: Exception { init() {}; init(msg: String) { super(msg) } }
open class Sequence<T> {
    func iterator(): MutableIterator<T> { return object {} }
}
class __ArrayLiteral {}

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

open class NodeList {
    init(size: Int64) {}
    var size: Int64 = 0
    func modCount(): Int64 { return 0 }
}
let EmptyNodeList = NodeList(0)
open class LinkedHashSet<T> {
    init() {}
    func add(e: T): Bool { return true }
    func addAll(c: Any): Bool { return true }
    func isEmpty(): Bool { return true }
    var size: Int64 = 0
}
func linkedSetOf<T>(): LinkedHashSet<T> { return LinkedHashSet() }

