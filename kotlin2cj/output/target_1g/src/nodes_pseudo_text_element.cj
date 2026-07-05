package target_1g

class PseudoTextElement <: Element {
    init(tag: Tag, baseUri: ?String, attributes: ?Attributes) {
        super(tag, baseUri, attributes)
    }
    public override func outerHtmlHead(accum: QuietAppendable, out: Document.OutputSettings) {}
    public override func outerHtmlTail(accum: QuietAppendable, out: Document.OutputSettings) {}
}
