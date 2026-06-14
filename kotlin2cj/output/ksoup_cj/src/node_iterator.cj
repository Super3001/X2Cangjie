package ksoup_cj

class NodeIterator<T> <: MutableIterator {
    let `type`: KClass<T>
    init(start: Node, `type`: KClass<T>) {
        this.`type` = `type`
        restart(start)
    }
    var root: ?Node = None
    var _next: ?T = None
    var current: ?Node = None
    var previous: ?Node = None
    var currentParent: ?Node = None
    func restart(start: Node) {
        if (`type`.isInstance(start)) {
            _next = (if (start is T) { start as T } else { None })
        }
        current = start
        previous = current
        root = previous
        currentParent = current?.parent()
    }
    public override func hasNext(): Bool {
        maybeFindNext()
        return _next.isSome()
    }
    public override func next(): T {
        maybeFindNext()
        if (_next.isNone()) {
            throw NoSuchElementException()
        }
        let result: T = _next.getOrThrow()
        previous = current
        current = _next
        currentParent = current?.parent()
        _next = None
        return result
    }
    func maybeFindNext() {
        if (let Some(_nextValue) <- _next) {
            let _next = _nextValue
            return
        }
        if ((currentParent.isSome()) && (current?.hasParent() != true)) {
            current = previous
        }
        _next = findNextNode()
    }
    func findNextNode(): ?T {
        var node: ?Node = current
        while (true) {
            if (node.getOrThrow().childNodeSize() > 0) {
                node = node.getOrThrow().childNode(0)
            } else if (root == node) {
                node = None
            } else if (node.getOrThrow().nextSibling().isSome()) {
                node = node.getOrThrow().nextSibling()
            } else {
                while (true) {
                    node = node?.parent()
                    if ((node.isNone()) || (root == node)) {
                        return None
                    }
                    if (node.getOrThrow().nextSibling().isSome()) {
                        node = node.getOrThrow().nextSibling()
                        break
                    }
                }
            }
            if (node.isNone()) {
                return None
            }
            if (`type`.isInstance(node)) {
                return (if (node is T) { node as T } else { None })
            }
        }

        throw Exception("unreachable")
    }
    public override func remove() {
        current?.remove()
    }
    static func from(start: Node): NodeIterator<Node> {
        return NodeIterator<Node>(start, Node)
    }
}
