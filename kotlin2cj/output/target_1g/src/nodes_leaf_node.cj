package target_1g

import std.collection.*

abstract class LeafNode <: Node {
    var value: ?Object = None
    init() {
        value = ""
    }
    init(coreValue: String) {
        value = coreValue
    }
    public open override func hasAttributes(): Bool {
        return (value is Attributes)
    }
    public open override func attributes(): Attributes {
        ensureAttributes()
        return (value as Attributes)
    }
    public open func ensureAttributes() {
        if (!hasAttributes()) {
            let coreValue = (if (value is String) { value as String } else { None })
            let attributes = Attributes()
            value = attributes
            attributes.put(nodeName(), coreValue)
        }
    }
    public open func coreValue(): String {
        return attr(nodeName())
    }
    public open override func parent(): ?Element {
        return _parentNode
    }
    public open override func nodeValue(): String {
        return coreValue()
    }
    public open func coreValue(value: ?String) {
        attr(nodeName(), value)
    }
    public open override func attr(attributeKey: String): String {
        return if (!hasAttributes()) {
            if (nodeName() == attributeKey) {
                (value as String)
            } else {
                EmptyString
            }
        } else {
            super.attr(attributeKey)
        }
    }
    public open override func attr(attributeKey: String, attributeValue: ?String): Node {
        if (!hasAttributes() && (attributeKey == nodeName())) {
            this.value = attributeValue
        } else {
            ensureAttributes()
            super.attr(attributeKey, attributeValue)
        }
        return this
    }
    public open override func hasAttr(attributeKey: String): Bool {
        ensureAttributes()
        return super.hasAttr(attributeKey)
    }
    public open override func removeAttr(attributeKey: String): Node {
        ensureAttributes()
        return super.removeAttr(attributeKey)
    }
    public open override func absUrl(attributeKey: String): String {
        ensureAttributes()
        return super.absUrl(attributeKey)
    }
    public open override func baseUri(): String {
        return if (let Some(_parentNodeValue) <- _parentNode) {
            let _parentNode = _parentNodeValue
            _parentNode.baseUri()
        } else {
            ""
        }
    }
    public open override func doSetBaseUri(baseUri: ?String) {}
    public open override func childNodeSize(): Int64 {
        return 0
    }
    public open override func empty(): Node {
        return this
    }
    public open override func ensureChildNodes(): ArrayList<Node> {
        return EmptyNodes
    }
    public open override func outerHtmlTail(accum: QuietAppendable, out: Document.OutputSettings) {}
    public open override func doClone(parent: ?Node): LeafNode {
        let clone = (super.doClone(parent) as LeafNode)
        if (hasAttributes()) {
            clone.value = (value as ?Attributes).clone()
        }
        return clone
    }
}
