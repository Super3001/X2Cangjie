package target_1g

interface NodeVisitor {
    func head(node: Node, depth: Int64): Unit
    func tail(node: Node, depth: Int64): Unit
    func traverse(root: Node): Unit
}
