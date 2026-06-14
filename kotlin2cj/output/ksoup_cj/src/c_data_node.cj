package ksoup_cj

class CDataNode <: TextNode {
    init(text: ?String) {
        super(text)
    }
    public override func nodeName(): String {
        return "#cdata"
    }
    public override func text(): String {
        return getWholeText()
    }
    public override func outerHtmlHead(accum: QuietAppendable, out: OutputSettings) {
        accum.append("<![CDATA[").append(getWholeText()).append("]]>")
    }
    public override func clone(): CDataNode {
        return this.clone()
    }
}
