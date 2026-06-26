package target_1d

// Stubs for external types referenced by parser package but defined elsewhere

public interface AutoCloseable {
    func close(): Unit
}

public interface KCloneable<T> {
    func clone(): T
}

public open class IOException <: Exception {
    init(message: String) { super(message) }
}

public open class UncheckedIOException <: Exception {
    init(cause: Exception) { super(cause.toString()) }
}

public open class IllegalArgumentException <: Exception {
    init(message: String) { super(message) }
}

public open class IllegalStateException <: Exception {
    init(message: String) { super(message) }
}

public open class IndexOutOfBoundsException <: Exception {
    init(message: String) { super(message) }
}

public interface MutableIterator<T> {
    func hasNext(): Bool
    func next(): T
}

public open class MutableList {
    public open func add(element: Any): Bool { return true }
    public open func add(all: Any): Bool { return true }
    public open func remove(element: Any): Bool { return false }
    public open func clear(): Unit {}
    public open func isEmpty(): Bool { return true }
    var size: Int64 = 0
}

public interface NodeVisitor {
    func head(node: Node, depth: Int64): Unit
    func tail(node: Node, depth: Int64): Unit
}
