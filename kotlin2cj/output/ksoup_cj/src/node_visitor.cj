package ksoup_cj

interface NodeVisitor {
    func head(node: Node, depth: Int64): Unit
    func tail(node: Node, depth: Int64): Unit
    func traverse(root: Node): Unit
}
