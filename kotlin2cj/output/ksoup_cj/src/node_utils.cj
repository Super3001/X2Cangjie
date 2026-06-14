package ksoup_cj

class NodeUtils {
    private init() {}
    public static let INSTANCE = NodeUtils()
    static func outputSettings(node: Node): OutputSettings {
        let owner: ?Document = node.ownerDocument()
        return owner?.outputSettings() ?? Document("").outputSettings()
    }
    static func parser(node: Node): Parser {
        let doc: ?Document = node.ownerDocument()
        return doc?.parser() ?? Parser(HtmlTreeBuilder())
    }
    // NOTE: inline reified function omitted — not supported by translator
}
