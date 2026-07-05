package target_1g

class NodeTraversor {
    private init() {}
    public static let INSTANCE = NodeTraversor()
    static func traverse(visitor: NodeVisitor, root: Node) {
        var node: ?Node = root
        var depth = 0
        while (node.isSome()) {
            let parent: ?Node = node.getOrThrow().parentNode()
            let origSize = parent?.childNodeSize() ?? 0
            let next: ?Node = node.getOrThrow().nextSibling()
            visitor.head(node, depth)
            if ((parent.isSome()) && !node.getOrThrow().hasParent()) {
                if (origSize == parent.getOrThrow().childNodeSize()) {
                    node = parent.getOrThrow().childNode(node.getOrThrow().siblingIndex())
                    continue
                }
                node = next
                if (node.isNone()) {
                    node = parent
                    while (true) {
                        depth -= 1
                        visitor.tail(node.getOrThrow(), depth)
                        if (node == root) {
                            break
                        }
                        if (node.getOrThrow().nextSibling().isSome()) {
                            node = node.getOrThrow().nextSibling()
                            break
                        }
                        node = node.getOrThrow().parentNode()
                        if (node.isNone()) {
                            break
                        }
                    }
                    if ((node == root) || (node.isNone())) {
                        break
                    }
                }
                continue
            }
            if (node.getOrThrow().childNodeSize() > 0) {
                node = node.getOrThrow().childNode(0)
                depth += 1
            } else {
                while (true) {
                    if (node.isNone()) {
                        throw Exception("as depth > 0, will have parent")
                    }
                    if (!((node.getOrThrow().nextSibling().isNone()) && (depth > 0))) {
                        break
                    }
                    visitor.tail(node, depth)
                    node = node.getOrThrow().parentNode()
                    depth -= 1
                }
                visitor.tail(node, depth)
                if (node == root) {
                    break
                }
                node = node.getOrThrow().nextSibling()
            }
        }
    }
    static func traverse(visitor: NodeVisitor, elements: Elements): Unit {
        for (it in elements) {
            traverse(visitor, it)
        }
    }
    static func filter(filter: NodeFilter, root: Node): FilterResult {
        var node: ?Node = root
        var depth = 0
        while (node.isSome()) {
            var result: FilterResult = filter.head(node, depth)
            if (result == FilterResult.STOP) {
                return result
            }
            if ((result == FilterResult.CONTINUE) && (node.getOrThrow().childNodeSize() > 0)) {
                node = node.getOrThrow().childNode(0)
                depth += 1
                continue
            }
            while (true) {
                if (!((node?.nextSibling().isNone()) && (depth > 0))) {
                    break
                }
                if ((result == FilterResult.CONTINUE) || (result == FilterResult.SKIP_CHILDREN)) {
                    result = filter.tail(node, depth)
                    if (result == FilterResult.STOP) {
                        return result
                    }
                }
                let prev: ?Node = node
                node = node?.parentNode()
                depth -= 1
                if (result == FilterResult.REMOVE) {
                    prev?.remove()
                }
                result = FilterResult.CONTINUE
            }
            if ((result == FilterResult.CONTINUE) || (result == FilterResult.SKIP_CHILDREN)) {
                result = filter.tail(node, depth)
                if (result == FilterResult.STOP) {
                    return result
                }
            }
            if (node == root) {
                return result
            }
            let prev: ?Node = node
            node = node?.nextSibling()
            if (result == FilterResult.REMOVE) {
                prev?.remove()
            }
        }
        return FilterResult.CONTINUE
    }
    static func filter(filter: NodeFilter, elements: Elements): Unit {
        for (el in elements) {
            if (filter(filter, el) == FilterResult.STOP) {
                return
            }
        }
    }
}
