package target_1g

interface NodeFilter {
    func head(node: Node, depth: Int64): FilterResult
    func tail(node: ?Node, depth: Int64): FilterResult
    func traverse(root: Node): Unit
}
