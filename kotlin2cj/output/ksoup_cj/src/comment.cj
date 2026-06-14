package ksoup_cj

import std.collection.*

class Comment <: LeafNode {
    init(data: String) {
        super(data)
    }
    public override func nodeName(): String {
        return "#comment"
    }
    func getData(): String {
        return coreValue()
    }
    func setData(data: ?String): Comment {
        coreValue(data)
        return this
    }
    public override func outerHtmlHead(accum: QuietAppendable, out: OutputSettings) {
        accum.append("<!--").append(getData()).append("-->")
    }
    public override func createClone(): Node {
        return Comment((value as String))
    }
    public override func clone(): Comment {
        return (super.clone() as Comment)
    }
    func isXmlDeclaration(): Bool {
        let data = getData()
        return isXmlDeclarationData(data)
    }
    func asXmlDeclaration(): ?XmlDeclaration {
        let fragment = ("<" + getData().toString()) + ">"
        let parser = Parser.xmlParser()
        let nodes: ArrayList<Node> = parser.parseFragmentInput(fragment, None, "")
        if (!nodes.isEmpty() && (nodes[0] is XmlDeclaration)) {
            return (nodes[0] as XmlDeclaration)
        }
        return None
    }
    static func isXmlDeclarationData(data: String): Bool {
        return (data.toRuneArray().size > 1) && (data.startsWith("!") || data.startsWith("?"))
    }
}
