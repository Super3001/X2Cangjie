package target_1b

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
    public open func putAll(from: MutableMap<K, V>): Unit {}
    public open func remove(key: K): ?V { return None }
}
open class MutableEntry<K, V> {
    public open func setValue(newValue: V): V { return newValue }
}
interface Entry<K, V> { func getKey(): K; func getValue(): V }
open class MutableList {
    public open func add(element: Object): Bool { return true }
    public open func addAll(elements: Object): Bool { return true }
    public open func remove(element: Object): Bool { return false }
    public open func clear(): Unit {}; public open func isEmpty(): Bool { return true }
}
open class RuntimeException <: Exception { init() {}; init(msg: String) { super(msg) } }
interface Appendable {
    func append(csq: Object): Appendable
    func append(csq: Object, start: Int64, end: Int64): Appendable
    func append(c: Rune): Appendable
}
open class Regex {
    init(pattern: String) {}
    func matches(input: String): Bool { return false }
    func replace(input: String, replacement: String): String { return "" }
    func findAll(input: String): ?Object { return None }
}
interface ToString { func toString(): String }
open class Object {
    public open func hashCode(): Int64 { return 0 }
    public open func equals(other: ?Object): Bool { return false }
    public open func toString(): String { return "" }
    public static func objectsEqual(a: ?Object, b: ?Object): Bool { return a.isNone() && b.isNone() || (a.isSome() && b.isSome() && a.getOrThrow().equals(b)) }
}

// Ksoup stubs
open class Node {
    init() {}
    public open func parent(): ?Element { return None }
    public open func childNodes(): ArrayList<Node> { return ArrayList() }
    public open func baseUri(): String { return "" }
    public open func normalName(): String { return "" }
}
open class Element <: Node {
    init(tag: String) {}
    public open func tagName(): String { return "" }
    public open func normalName(): String { return "" }
    public open func attributes(): Attributes { return Attributes() }
    public open func clearAttributes(): Unit {}
    public open func appendChild(child: Node): Unit {}
    public open func insertChildren(index: Int64, children: ArrayList<Node>): Unit {}
    public open func body(): Element { return this }
    public open func head(): Element { return this }
    public open func shallowClone(): Element { return Element("") }
    public open func outputSettings(settings: Object): Unit {}
    public open func outputSettings(): ?Object { return None }
    public open func absUrl(key: String): String { return "" }
    public open func nameIs(name: String): Bool { return false }
    public open func parent(): ?Element { return None }
    public static func createShell(baseUri: String): Document { return Document(baseUri) }
}
open class Document <: Element {
    init(baseUri: String) { super("") }
    public static func createShell(baseUri: String): Document { return Document(baseUri) }
}
open class TextNode <: Node {
    init(text: String) {}
    public func getWholeText(): String { return "" }
    public func isBlank(): Bool { return true }
}
open class DataNode <: Node {
    init(data: String) {}
    public func getWholeData(): String { return "" }
}
class Attribute {
    var key: String = ""
    var value: String = ""
    init(key: String, value: String) {
        this.key = key
        this.value = value
    }
    public func setValue(value: String): Unit { this.value = value }
}
class _AttrIter <: Iterator<Attribute> {
    public func hasNext(): Bool { return false }
    public func next(): ?Attribute { return None }
}
class Attributes <: Iterable<Attribute> {
    init() {}
    public func put(attr: Attribute): Unit {}
    public func put(key: String, value: String): Unit {}
    public func addAll(elements: Object): Unit {}
    public func remove(key: String): Unit {}
    public func hasKeyIgnoreCase(key: String): Bool { return false }
    public func getIgnoreCase(key: String): String { return "" }
    public func iterator(): Iterator<Attribute> { return _AttrIter() }
    public func isEmpty(): Bool { return true }
    public operator func [](key: String): ?String { return None }
    public func get(key: String): ?String { return None }
    public func get(key: AttributeKey): ?AttributeValue { return None }
}
class Parser {
    public static func parseFragment(bodyHtml: String, context: Element, baseUri: String, errorList: ParseErrorList): ArrayList<Node> {
        return ArrayList()
    }
}
class ParseErrorList {
    init(maxSize: Int64) {}
    public func isEmpty(): Bool { return true }
    public static func tracking(maxSize: Int64): ParseErrorList { return ParseErrorList(maxSize) }
    public static func noTracking(): ParseErrorList { return ParseErrorList(0) }
}
interface NodeVisitor {
    func head(node: Node, depth: Int64): Unit
    func tail(node: Node, depth: Int64): Unit
}
class NodeTraversor {
    init(visitor: NodeVisitor) {}
    public func traverse(root: Node): Unit {}
}
class SharedConstants {
    static let DummyUri = ""
}
class Validate {
    public static func notEmpty(s: String): Unit {}
    public static func isFalse(condition: Bool, msg: String): Unit {}
    public static func isTrue(condition: Bool, msg: String): Unit {}
}
