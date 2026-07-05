package target_1g

import std.collection.*

open class Nodes<T> <: MutableList & ToString {
    let delegateList: ArrayList<T>
    init(delegateList!: ArrayList<T> = ArrayList()) {
        this.delegateList = delegateList
    }
    public open override func equals(other: ?Object): Bool {
        if (this == other) {
            return true
        }
        if (!(other is Nodes<Object>)) {
            return false
        }
        if (this.size != other.getOrThrow().size) {
            return false
        }
        for (i in (0..this.size)) {
            if (this[i] != other[i]) {
                return false
            }
        }
        return true
    }
    public open override func hashCode(): Int64 {
        return delegateList.hashCode()
    }
    public static func invoke<T>(collection: ArrayList<T>): Nodes<T> where T <: Node {
        return Nodes(delegateList: collection)
    }
    public static func invoke<T>(): Nodes<T> where T <: Node {
        return Nodes()
    }
    init(initialCapacity: Int64) {
        this(ArrayList<T>([initialCapacity]))
    }
    init(nodes: ArrayList<T>) {
        this(ArrayList<T>([nodes]))
    }
    init(nodes: Array<T>) {
        this(ArrayList<T>([nodes.asList()]))
    }
    public open override func iterator(): MutableIterator<T> {
        return NodesIterator(delegateList.iterator())
    }
    public open func clone(): Nodes<T> {
        let clone = Nodes<T>(size)
        for (node in this) {
            clone.add((node.clone() as T))
        }
        return clone
    }
    public open func asList(): ArrayList<T> {
        return ArrayList([this])
    }
    public open func remove(): Nodes<T> {
        for (node in this) {
            node.remove()
        }
        return this
    }
    public open func outerHtml(): String {
        return String.join(collectArray<String>(this.iterator().map({ it => it.outerHtml() })), delimiter: "\n")
    }
    public open override func toString(): String {
        return outerHtml()
    }
    public open func before(html: String): Nodes<T> {
        for (node in this) {
            node.before(html)
        }
        return this
    }
    public open func after(html: String): Nodes<T> {
        for (node in this) {
            node.after(html)
        }
        return this
    }
    public open func wrap(html: String): Nodes<T> {
        Validate.notEmpty(html)
        for (node in this) {
            node.wrap(html)
        }
        return this
    }
    public open func first(): ?T {
        return if (isEmpty()) {
            None
        } else {
            get(0)
        }
    }
    public open func last(): ?T {
        return if (isEmpty()) {
            None
        } else {
            get(size - 1)
        }
    }
    public open override func set(index: Int64, element: T): T {
        Validate.expectNotNull(element)
        let old = delegateList.set(index, element)
        old.replaceWith(element)
        return old
    }
    public open override func removeAt(index: Int64): T {
        let old = delegateList.remove(at: index)
        old.remove()
        return old
    }
    public open override func remove(element: T): Bool {
        let index = this.indexOf(element)
        if (index == -1) {
            return false
        } else {
            removeAt(index)
            return true
        }
    }
    public open func deselect(index: Int64): T {
        return delegateList.remove(at: index)
    }
    public open func deselect(element: ?Object): Bool {
        return delegateList.remove(element)
    }
    public open override func clear() {
        remove()
        delegateList.clear()
    }
    public open func deselectAll() {
        delegateList.clear()
    }
    public open override func removeAll(elements: ArrayList<T>): Bool {
        var anyRemoved = false
        for (element in elements) {
            anyRemoved = this.remove(element) || anyRemoved
        }
        return anyRemoved
    }
    public open override func retainAll(elements: ArrayList<T>): Bool {
        let toRemove = ArrayList<T>()
        for (element in this) {
            if (!elements.contains(element)) {
                toRemove.add(element)
            }
        }
        return if (!(toRemove.isEmpty())) {
            removeAll(toRemove)
            true
        } else {
            false
        }
    }
    public open func removeIf(predicate: (T) -> Bool): Bool {
        let toRemove = ArrayList<T>()
        for (node in this) {
            if (predicate(node)) {
                toRemove.add(node)
            }
        }
        return if (!(toRemove.isEmpty())) {
            removeAll(toRemove)
            true
        } else {
            false
        }
    }
    public open func replaceAll(`operator`: (T) -> T) {
        for (i in (0..this.size)) {
            this[i] = `operator`(this[i])
        }
    }
}
