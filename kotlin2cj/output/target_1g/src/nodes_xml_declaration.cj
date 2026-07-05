package target_1g

class XmlDeclaration <: LeafNode & ToString {
    let isDeclaration: Bool
    init(name: String, isDeclaration: Bool) {
        super(name)
        this.isDeclaration = isDeclaration
    }
    public override func nodeName(): String {
        return "#declaration"
    }
    func name(): String {
        return coreValue()
    }
    func getWholeDeclaration(): String {
        let sb: StringBuilder = StringUtil.borrowBuilder()
        getWholeDeclaration(QuietAppendable.wrap(sb), Document.OutputSettings())
        return StringUtil.releaseBuilder(sb).trimAscii()
    }
    func getWholeDeclaration(accum: QuietAppendable, out: Document.OutputSettings) {
        for (attribute in attributes()) {
            let key: String = attribute.key
            let value: String = attribute.value
            if (key != nodeName()) {
                accum.append(r' ')
                accum.append(key)
                if (!(value.isEmpty())) {
                    accum.append("=\"")
                    Entities.escape(accum, value, out, Entities.ForAttribute)
                    accum.append(r'"')
                }
            }
        }
    }
    public override func outerHtmlHead(accum: QuietAppendable, out: Document.OutputSettings) {
        accum.append("<").append(if (isDeclaration) {
            "!"
        } else {
            "?"
        }).append(coreValue())
        getWholeDeclaration(accum, out)
        accum.append(if (isDeclaration) {
            ""
        } else {
            "?"
        }).append(">")
    }
    public override func outerHtmlTail(accum: QuietAppendable, out: Document.OutputSettings) {}
    public override func toString(): String {
        return outerHtml()
    }
    public override func createClone(): Node {
        return XmlDeclaration((this.value as String), this.isDeclaration)
    }
    public override func clone(): XmlDeclaration {
        return this.clone()
    }
}
