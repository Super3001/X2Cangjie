package target_1g

class NodeUtils {
    private init() {}
    public static let INSTANCE = NodeUtils()
    static func outputSettings(node: Node): Document.OutputSettings {
        let owner: ?Document = node.ownerDocument()
        return owner?.outputSettings() ?? Document("").outputSettings()
    }
    static func parser(node: Node): Parser {
        let doc: ?Document = node.ownerDocument()
        return doc?.parser() ?? Parser(HtmlTreeBuilder())
    }
    static func stream<T>(start: Node, `type`: KClass<T>): Sequence<T> where T <: Node {
        let iterator: NodeIterator<T> = NodeIterator(start, `type`)
        return iterator.asSequence()
    }
}
