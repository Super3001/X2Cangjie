package target_1g

func __k2cjRuneSlice(input: String, start: Int64, end: Int64): String {
    let _r = input.toRuneArray()
    let _out = Array<Rune>(end - start, { _ => r'\u{0000}' })
    var _i = 0
    while (_i < end - start) {
        _out[_i] = _r[start + _i]
        _i++
    }
    String(_out)
}

open class TextNode <: LeafNode & ToString {
    init(text: String) {
        super(text)
    }
    public open override func nodeName(): String {
        return "#text"
    }
    public open func text(): String {
        return StringUtil.normaliseWhitespace(getWholeText())
    }
    public open func text(text: ?String): TextNode {
        coreValue(text)
        return this
    }
    public open func getWholeText(): String {
        return coreValue()
    }
    public open func isBlank(): Bool {
        return StringUtil.isBlank(coreValue())
    }
    public open func splitText(offset: Int64): TextNode {
        let text: String = coreValue()
        Validate.isTrue(offset >= 0, "Split offset must be not be negative")
        Validate.isTrue(offset < text.toRuneArray().size, "Split offset must not be greater than current text length")
        let head = __k2cjRuneSlice(text, 0, offset)
        let tail = __k2cjRuneSlice(text, offset, text.toRuneArray().size)
        text(head)
        let tailNode = TextNode(tail)
        if (let Some(_parentNodeValue) <- _parentNode) {
            let _parentNode = _parentNodeValue
            _parentNode.addChildren(siblingIndex() + 1, tailNode)
        }
        return tailNode
    }
    public open override func outerHtmlHead(accum: QuietAppendable, out: Document.OutputSettings) {
        Entities.escape(accum, coreValue(), out, Entities.ForText)
    }
    public open override func toString(): String {
        return outerHtml()
    }
    public open override func createClone(): Node {
        let clone = TextNode("")
        clone.value = this.value
        return clone
    }
    public open override func clone(): TextNode {
        return (super.clone() as TextNode)
    }
    public static func createFromEncoded(encodedText: String): TextNode {
        let text: String = Entities.unescape(encodedText)
        return TextNode(text)
    }
    public static func normaliseWhitespace(text: String): String {
        return StringUtil.normaliseWhitespace(text)
    }
    public static func stripLeadingWhitespace(text: String): String {
        return text.replaceFirst("^\\s+".toRegex(), "")
    }
    public static func lastCharIsWhitespace(sb: StringBuilder): Bool {
        return (sb.toString().size > 0) && (sb[sb.toRuneArray().size - 1] == r' ')
    }
}
