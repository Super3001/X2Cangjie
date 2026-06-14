package ksoup_cj

import std.collection.*

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

abstract class Node <: KCloneable {
    var _parentNode: ?Element = None
    var _siblingIndex: Int64 = 0
    public func nodeName(): String
    public open func normalName(): String {
        return nodeName()
    }
    public open func nodeValue(): String {
        return ""
    }
    public open func nameIs(normalName: ?String): Bool {
        return normalName() == normalName
    }
    public open func parentNameIs(normalName: String): Bool {
        return (_parentNode.isSome()) && (_parentNode.getOrThrow().normalName() == normalName)
    }
    public open func parentElementIs(normalName: String, namespace: String): Bool {
        return ((_parentNode.isSome()) && (_parentNode is Element)) && (_parentNode as Element).elementIs(normalName, namespace)
    }
    public func hasAttributes(): Bool
    public open func hasParent(): Bool {
        return _parentNode.isSome()
    }
    public open func attr(attributeKey: String): String {
        if (!hasAttributes()) {
            return Node.EmptyString
        }
        let value = attributes().getIgnoreCase(attributeKey)
        return if (!(value.isEmpty())) {
            value
        } else if (attributeKey.startsWith("abs:")) {
            absUrl(__k2cjRuneSlice(attributeKey, "abs:".toRuneArray().size, attributeKey.toRuneArray().size))
        } else {
            ""
        }
    }
    public func attributes(): Attributes
    public open func attributesSize(): Int64 {
        return if (hasAttributes()) {
            attributes().size()
        } else {
            0
        }
    }
    public open func attr(attributeKey: String, attributeValue: ?String): Node {
        let doc = ownerDocument()
        let settings = if (let Some(docValue) <- doc) {
            let doc = docValue
            doc.parser()?.settings()
        } else {
            ParseSettings.htmlDefault
        }
        let attributeKey = settings.normalizeAttribute(attributeKey)
        attributes().putIgnoreCase(attributeKey, attributeValue)
        return this
    }
    public open func hasAttr(attributeKey: String): Bool {
        if (!hasAttributes()) {
            return false
        }
        if (attributeKey.startsWith("abs:")) {
            let key = __k2cjRuneSlice(attributeKey, "abs:".toRuneArray().size, attributeKey.toRuneArray().size)
            if (attributes().hasKeyIgnoreCase(key) && !(absUrl(key).isEmpty())) {
                return true
            }
        }
        return attributes().hasKeyIgnoreCase(attributeKey)
    }
    public open func removeAttr(attributeKey: String): Node {
        if (hasAttributes()) {
            attributes().removeIgnoreCase(attributeKey)
        }
        return this
    }
    public open func clearAttributes(): Node {
        if (hasAttributes()) {
            let it: MutableIterator<Attribute> = attributes().iterator()
            while (it.hasNext()) {
                it.next()
                it.remove()
            }
        }
        return this
    }
    public func baseUri(): String
    public func doSetBaseUri(baseUri: ?String): Unit
    public open func setBaseUri(baseUri: String) {
        doSetBaseUri(baseUri)
    }
    public open func absUrl(attributeKey: String): String {
        Validate.notEmpty(attributeKey)
        return if (!(hasAttributes() && attributes().hasKeyIgnoreCase(attributeKey))) {
            ""
        } else {
            StringUtil.resolve(baseUri(), attributes().getIgnoreCase(attributeKey))
        }
    }
    public func ensureChildNodes(): ArrayList<Node>
    public open func childNode(index: Int64): Node {
        return ensureChildNodes()[index]
    }
    public open func childNodes(): ArrayList<Node> {
        if (childNodeSize() == 0) {
            return EmptyNodes
        }
        let children: ArrayList<Node> = ensureChildNodes()
        let rewrap: ArrayList<Node> = ArrayList<Node>([children.size])
        rewrap.add(all: children)
        return rewrap
    }
    public open func childNodesCopy(): ArrayList<Node> {
        let nodes: ArrayList<Node> = ensureChildNodes()
        let children: ArrayList<Node> = ArrayList<Node>([nodes.size])
        for (node in nodes) {
            children.add(node.clone())
        }
        return children
    }
    public func childNodeSize(): Int64
    public open func childNodesAsArray(): Array<Node> {
        return ensureChildNodes().toTypedArray()
    }
    public func empty(): ?Node
    public open func parent(): ?Node {
        return _parentNode
    }
    public open func parentElement(): ?Element {
        return _parentNode
    }
    public open func parentNode(): ?Node {
        return _parentNode
    }
    public open func root(): Node {
        var node: Node = this
        while (node._parentNode.isSome()) {
            node = node._parentNode.getOrThrow()
        }
        return node
    }
    public open func ownerDocument(): ?Document {
        var node: ?Node = this
        while (node.isSome()) {
            if ((node is Document)) {
                return node
            }
            node = node.getOrThrow()._parentNode
        }
        return None
    }
    public open func remove() {
        if (let Some(_parentNodeValue) <- _parentNode) {
            let _parentNode = _parentNodeValue
            _parentNode.getOrThrow().removeChild(this)
        }
    }
    public open func before(html: String): Node {
        addSiblingHtml(siblingIndex(), html)
        return this
    }
    public open func before(node: Node): Node {
        if (node.parentNode() == parentNode()) {
            node.remove()
        }
        parentNode()?.addChildren([siblingIndex(), node])
        return this
    }
    public open func after(html: String): Node {
        addSiblingHtml(siblingIndex() + 1, html)
        return this
    }
    public open func after(node: Node): Node {
        if (node.parentNode() == parentNode()) {
            node.remove()
        }
        parentNode().getOrThrow().addChildren([siblingIndex() + 1, node])
        return this
    }
    public open func addSiblingHtml(index: Int64, html: String) {
        let context: ?Element = if ((_parentNode is Element)) {
            (_parentNode as ?Element)
        } else {
            None
        }
        let nodes: ArrayList<Node> = NodeUtils.parser(this).parseFragmentInput(html, context, baseUri())
        _parentNode?.addChildren([index, nodes.toTypedArray()])
    }
    public open func wrap(html: String): Node {
        Validate.notEmpty(html)
        let context: Element = if ((_parentNode.isSome()) && (_parentNode is Element)) {
            (_parentNode as Element)
        } else {
            (if (this is Element) { this as Element } else { None })
        }
        let wrapChildren: ArrayList<Node> = NodeUtils.parser(this).parseFragmentInput(html, context, baseUri())
        let wrapNode = (if (wrapChildren[0] is Element) { wrapChildren[0] as Element } else { None }) ?? return
        this
        let wrap: Element = wrapNode
        let deepest: Element = getDeepChild(wrap)
        if (let Some(_parentNodeValue) <- _parentNode) {
            let _parentNode = _parentNodeValue
            _parentNode.getOrThrow().replaceChild(this, wrap)
        }
        deepest.addChildren([this])
        if (!(wrapChildren.isEmpty())) {
            for (i in (0..wrapChildren.size)) {
                let remainder = wrapChildren[i]
                if (wrap == remainder) {
                    continue
                }
                if (remainder._parentNode.isSome()) {
                    remainder._parentNode.removeChild(remainder)
                }
                wrap.after(remainder)
            }
        }
        return this
    }
    public open func unwrap(): ?Node {
        let firstChild = firstChild()
        _parentNode.getOrThrow().addChildren([siblingIndex(), childNodesAsArray()])
        this.remove()
        return firstChild
    }
    public open func replaceWith(inNode: Node) {
        if (_parentNode.isNone()) {
            _parentNode = inNode._parentNode
        }
        _parentNode.getOrThrow().replaceChild(this, inNode)
    }
    public open func setParentNode(parentNode: Node) {
        if (this._parentNode.isSome()) {
            this._parentNode.removeChild(this)
        }
        this._parentNode = (parentNode as Element)
    }
    public open func replaceChild(out: Node, inNode: Node) {
        Validate.isTrue(out._parentNode == this)
        if (out == inNode) {
            return
        }
        if (inNode._parentNode.isSome()) {
            inNode._parentNode.getOrThrow().removeChild(inNode)
        }
        let index = out.siblingIndex()
        ensureChildNodes()[index] = inNode
        inNode._parentNode = (this as Element)
        inNode._siblingIndex = index
        out._parentNode = None
        this.childNodes.incrementMod()
    }
    public open func removeChild(out: Node) {
        Validate.isTrue(out._parentNode == this)
        let el: Element = (this as Element)
        if (el.hasValidChildren()) {
            ensureChildNodes().remove(at: out._siblingIndex)
        } else {
            ensureChildNodes().remove(out)
        }
        el.invalidateChildren()
        out._parentNode = None
    }
    public open func addChildren(children: Array<Node>) {
        let nodes = ensureChildNodes()
        for (child in children) {
            reparentChild(child)
            nodes.add(child)
            child._siblingIndex = nodes.size - 1
        }
    }
    public open func addChildren(index: Int64, children: Array<Node>) {
        if (children.isEmpty()) {
            return
        }
        let nodes = ensureChildNodes()
        let firstParent = children[0].parent()
        if ((firstParent.isSome()) && (firstParent.childNodeSize() == children.size)) {
            var sameList = true
            let firstParentNodes: ArrayList<Node> = firstParent.ensureChildNodes()
            var i = children.size
            while (i -= 1 > 0) {
                if (children[i] != firstParentNodes[i]) {
                    sameList = false
                    break
                }
            }
            if (sameList) {
                firstParent.empty()
                nodes.addAll(index, ArrayList(children))
                i = children.size
                while (i -= 1 > 0) {
                    children[i]._parentNode = (this as Element)
                }
                (this as Element).invalidateChildren()
                return
            }
        }
        for (child in children) {
            reparentChild(child)
        }
        nodes.addAll(index, ArrayList(children))
        (this as Element).invalidateChildren()
    }
    public open func reparentChild(child: Node) {
        child.setParentNode(this)
    }
    public open func siblingNodes(): ArrayList<Node> {
        if (_parentNode.isNone()) {
            return emptyList()
        }
        let nodes: ArrayList<Node> = _parentNode.getOrThrow().ensureChildNodes()
        let siblings: ArrayList<Node> = ArrayList<Node>([nodes.size - 1])
        for (node in nodes) {
            if (node != this) {
                siblings.add(node)
            }
        }
        return siblings
    }
    public open func nextSibling(): ?Node {
        if (_parentNode.isNone()) {
            return None
        }
        let siblings: ArrayList<Node> = _parentNode.getOrThrow().ensureChildNodes()
        let index = siblingIndex() + 1
        if (siblings.size > index) {
            let node: Node = siblings[index]
            return node
        } else {
            return None
        }
    }
    public open func previousSibling(): ?Node {
        if (_parentNode.isNone()) {
            return None
        }
        return if (siblingIndex() > 0) {
            _parentNode.getOrThrow().ensureChildNodes()[_siblingIndex - 1]
        } else {
            None
        }
    }
    public open func siblingIndex(): Int64 {
        if ((_parentNode.isSome()) && !_parentNode.getOrThrow().childNodes.validChildren) {
            _parentNode.getOrThrow().reindexChildren()
        }
        return _siblingIndex
    }
    public open func firstChild(): ?Node {
        return if (childNodeSize() == 0) {
            None
        } else {
            ensureChildNodes()[0]
        }
    }
    public open func lastChild(): ?Node {
        let size = childNodeSize()
        if (size == 0) {
            return None
        }
        let children: ArrayList<Node> = ensureChildNodes()
        return children[size - 1]
    }
    public open func firstSibling(): ?Node {
        return if (let Some(_parentNodeValue) <- _parentNode) {
            let _parentNode = _parentNodeValue
            _parentNode.getOrThrow().firstChild()
        } else {
            this
        }
    }
    public open func lastSibling(): ?Node {
        return if (let Some(_parentNodeValue) <- _parentNode) {
            let _parentNode = _parentNodeValue
            _parentNode.getOrThrow().lastChild()
        } else {
            this
        }
    }
    public open func nextElementSibling(): ?Element {
        var next: ?Node = this
        while ({ it =>
            let _also_it = next?.nextSibling()
            let _it = _also_it
            next = it
            return _also_it
        }().isSome()) {
            if ((next is Element)) {
                return next
            }
        }
        return None
    }
    public open func previousElementSibling(): ?Element {
        var prev: ?Node = this
        while ({ it =>
            let _also_it = prev?.previousSibling()
            let _it = _also_it
            prev = it
            return _also_it
        }().isSome()) {
            if ((prev is Element)) {
                return prev
            }
        }
        return None
    }
    public open func traverse(nodeVisitor: NodeVisitor): Node {
        nodeVisitor.traverse(this)
        return this
    }
    public open func forEachNode(action: Consumer<Node>): Node {
        for (it in nodeStream()) {
            action.accept(it)
        }
        return this
    }
    public open func filter(nodeFilter: NodeFilter): Node {
        nodeFilter.traverse(this)
        return this
    }
    public open func nodeStream(): Sequence<Node> {
        return NodeUtils.stream(this, Node)
    }
    // NOTE: inline reified function omitted — not supported by translator
}
