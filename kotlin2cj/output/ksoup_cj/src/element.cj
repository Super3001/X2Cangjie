package ksoup_cj

import std.collection.*

open class Element <: Node & Iterable {
    let lock = Synchronizable()
    var _tag: Tag
    var _baseUri: ?String = None
    var childNodes: NodeList = EmptyNodeList
    var _attributes: ?Attributes = None
    init(tag: String, namespace: String) {
        this(Tag.valueOf(tag, namespace, ParseSettings.preserveCase), None)
    }
    init(tag: String) {
        this(tag, Parser.NamespaceHtml)
    }
    init(tag: Tag, baseUri: ?String, attributes: ?Attributes) {
        childNodes = EmptyNodeList
        this.attributes = attributes
        this.tag = tag
        _baseUri = baseUri
        if (!StringUtil.isBlank(baseUri)) {
            this.setBaseUri(baseUri.getOrThrow())
        }
    }
    init(tag: Tag, baseUri: ?String) {
        this(tag, baseUri, None)
    }
    public open func hasChildNodes(): Bool {
        return childNodes != EmptyNodeList
    }
    public open override func ensureChildNodes(): ArrayList<Node> {
        if (childNodes == EmptyNodeList) {
            childNodes = NodeList(4)
        }
        return childNodes
    }
    public open override func hasAttributes(): Bool {
        return _attributes.isSome()
    }
    public open override func attributes(): Attributes {
        if (_attributes.isNone()) {
            _attributes = Attributes()
        }
        return _attributes.getOrThrow()
    }
    public open override func baseUri(): String {
        let baseUri = searchUpForAttribute(this, BaseUriKey)
        return baseUri ?? ""
    }
    public open override func doSetBaseUri(baseUri: ?String) {
        _attributes().put(BaseUriKey, baseUri)
    }
    public open override func childNodeSize(): Int64 {
        return childNodes.size
    }
    public open override func nodeName(): String {
        return _tag.tagName
    }
    public open func tagName(): String {
        return _tag.tagName
    }
    public open override func normalName(): String {
        return _tag.normalName()
    }
    public open func elementIs(normalName: ?String, namespace: String): Bool {
        return (_tag.normalName() == normalName) && (_tag.namespace() == namespace)
    }
    public open func tagName(tagName: String, namespace: String): Element {
        Validate.notEmptyParam(tagName, "tagName")
        Validate.notEmptyParam(namespace, "namespace")
        let parser = parser(this)
        _tag = parser.tagSet().valueOf(tagName, namespace, parser.settings())
        return this
    }
    public open func tag(): Tag {
        return _tag
    }
    public open func tag(tag: Tag): Element {
        this.tag = tag
        return this
    }
    public open func isBlock(): Bool {
        return _tag.isBlock()
    }
    public open func id(): String {
        return if (let Some(_attributesValue) <- _attributes) {
            let _attributes = _attributesValue
            _attributes.getOrThrow().getIgnoreCase("id")
        } else {
            ""
        }
    }
    public open func id(id: String): Element {
        attr("id", id)
        return this
    }
    public open override func attr(attributeKey: String, attributeValue: ?String): Element {
        super.attr(attributeKey, attributeValue)
        return this
    }
    public open func attr(attributeKey: String, attributeValue: Bool): Element {
        _attributes().put(attributeKey, attributeValue)
        return this
    }
    public open func attribute(key: ?String): ?Attribute {
        return if (hasAttributes()) {
            _attributes().attribute(key)
        } else {
            None
        }
    }
    public open func dataset(): Attributes.Dataset {
        return _attributes().dataset()
    }
    public open override func parent(): ?Element {
        return (if (_parentNode is Element) { _parentNode as Element } else { None })
    }
    public open func parents(): Elements {
        let parents = Elements()
        var parent = parent()
        while ((parent.isSome()) && !parent.nameIs("#root")) {
            parents.add(parent)
            parent = parent.parent()
        }
        return parents
    }
    public open func child(index: Int64): Element {
        Validate.isTrue(index >= 0, "Index must be >= 0")
        let cached: ?ArrayList<Element> = cachedChildren()
        if (let Some(cachedValue) <- cached) {
            let cached = cachedValue
            return cached[index]
        }
        let size = childNodes.size
        var i = 0
        var e = 0
        while (i < size) {
            let node: ?Node = childNodes[i]
            if ((node is Element)) {
                if (e += 1 == index) {
                    return node
                }
            }
            i += 1
        }
        throw IndexOutOfBoundsException("No child at index: ${index}")
    }
    public open func childrenSize(): Int64 {
        if (childNodeSize() == 0) {
            return 0
        }
        return childElementsList().size
    }
    public open func children(): Elements {
        return Elements(childElementsList())
    }
    public open func childElementsList(): ArrayList<Element> {
        if (childNodeSize() == 0) {
            return EmptyChildren
        }
        return lock.synchronize({ =>
            var children: ?ArrayList<Element> = cachedChildren()
            if (children.isNone()) {
                children = filterNodes<Element>(Element)
                stashChildren(children)
            }
            children
        })
    }
    public open func cachedChildren(): ?ArrayList<Element> {
        if ((_attributes.isNone()) || !_attributes.getOrThrow().hasUserData()) {
            return None
        }
        let userData = _attributes.getOrThrow().userData()
        let ref = (if (userData[childElsKey] is WeakReference<ArrayList<Element>>) { userData[childElsKey] as WeakReference<ArrayList<Element>> } else { None })
        let els = ref?.get()
        if (let Some(elsValue) <- els) {
            let els = elsValue
            let modCount = (if (userData[childElsMod] is Int64) { userData[childElsMod] as Int64 } else { None })
            if ((modCount.isSome()) && (modCount == childNodes.modCount())) {
                return els
            }
        }
        return None
    }
    public open func stashChildren(els: ArrayList<Element>) {
        let userData = _attributes().userData()
        let ref = WeakReference(els)
        userData[childElsKey] = ref
        userData[childElsMod] = childNodes.modCount()
    }
    public open func stream(): Sequence<Element> {
        return NodeUtils.stream(this, Element)
    }
    // NOTE: inline reified function omitted — not supported by translator
}
