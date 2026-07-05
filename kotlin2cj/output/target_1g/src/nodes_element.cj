package target_1g

import std.collection.*

open class Element <: Node & Iterable {
    let lock = Synchronizable()
    var _tag: Tag
    var _baseUri: ?String = None
    var childNodes: NodeList = Element.EmptyNodeList()
    var _attributes: ?Attributes = None
    init(tag: String, namespace: String) {
        this(Tag.valueOf(tag, namespace, ParseSettings.preserveCase), None)
    }
    init(tag: String) {
        this(tag)
    }
    init(tag: Tag, baseUri: ?String, attributes: ?Attributes) {
        childNodes = Element.EmptyNodeList()
        this.attributes = attributes
        this.tag = tag
        _baseUri = baseUri
        if (!StringUtil.isBlank(baseUri)) {
            this.setBaseUri(baseUri.getOrThrow())
        }
    }
    init(tag: Tag, baseUri: ?String) {
        this(tag, baseUri)
    }
    public open func hasChildNodes(): Bool {
        return childNodes != Element.EmptyNodeList()
    }
    public open override func ensureChildNodes(): ArrayList<Node> {
        if (childNodes == Element.EmptyNodeList()) {
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
        let baseUri = searchUpForAttribute(this, Element.BaseUriKey())
        return baseUri ?? ""
    }
    public open override func doSetBaseUri(baseUri: ?String) {
        _attributes().put(Element.BaseUriKey(), baseUri)
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
    public open func tagName(tagName: String, namespace!: String): Element {
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
            return Element.EmptyChildren()
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
        let ref = (if (userData[Element.childElsKey] is WeakReference<ArrayList<Element>>) { userData[Element.childElsKey] as WeakReference<ArrayList<Element>> } else { None })
        let els = ref?.get()
        if (let Some(elsValue) <- els) {
            let els = elsValue
            let modCount = (if (userData[Element.childElsMod] is Int64) { userData[Element.childElsMod] as Int64 } else { None })
            if ((modCount.isSome()) && (modCount == childNodes.modCount())) {
                return els
            }
        }
        return None
    }
    public open func stashChildren(els: ArrayList<Element>) {
        let userData = _attributes().userData()
        let ref = WeakReference(els)
        userData[Element.childElsKey] = ref
        userData[Element.childElsMod] = childNodes.modCount()
    }
    public open func stream(): Sequence<Element> {
        return NodeUtils.stream(this, Element)
    }
    public open func filterNodes<reified>(clazz: KClass<T>): ArrayList<T> where reified <: Object {
        return childNodes.filterIsInstance()
    }
    public open func textNodes(): ArrayList<TextNode> {
        return filterNodes(TextNode)
    }
    public open func dataNodes(): ArrayList<DataNode> {
        return filterNodes(DataNode)
    }
    public open func select(cssQuery: String): Elements {
        return Selector.select(cssQuery, this)
    }
    public open func select(evaluator: Evaluator): Elements {
        return Selector.select(evaluator, this)
    }
    public open func selectStream(cssQuery: String): Sequence<Element> {
        return Selector.selectStream(cssQuery, this)
    }
    public open func selectFirst(cssQuery: String): ?Element {
        return Selector.selectFirst(cssQuery, this)
    }
    public open func selectFirst(evaluator: Evaluator): ?Element {
        return findFirst(evaluator, this)
    }
    public open func expectFirst(cssQuery: String): Element {
        return Validate.expectNotNull(Selector.selectFirst(cssQuery, this), if (parent().isSome()) {
            "No elements matched the query '${cssQuery}' on element '${this.tagName()}'."
        } else {
            "No elements matched the query '${cssQuery}' in the document."
        })
    }
    public open func selectNodes(evaluator: Evaluator): Nodes<Node> {
        return selectNodes(evaluator, Node)
    }
    public open func selectNodes(cssQuery: String): Nodes<Node> {
        return selectNodes(cssQuery, Node)
    }
    public open func selectNodes<T>(evaluator: Evaluator, `type`: KClass<T>): Nodes<T> where T <: Node {
        return Collector.collectNodes(evaluator, this, `type`)
    }
    public open func selectNodes<T>(cssQuery: String, `type`: KClass<T>): Nodes<T> where T <: Node {
        Validate.notEmpty(cssQuery)
        return selectNodes(Selector.evaluatorOf(cssQuery), `type`)
    }
    public open func selectFirstNode<T>(cssQuery: String, `type`: KClass<T>): ?T where T <: Node {
        return selectFirstNode(evaluatorOf(cssQuery), `type`)
    }
    public open func selectFirstNode<T>(evaluator: Evaluator, `type`: KClass<T>): ?T where T <: Node {
        return Collector.findFirstNode(evaluator, this, `type`)
    }
    public open func expectFirstNode<T>(cssQuery: String, `type`: KClass<T>): T where T <: Node {
        return Validate.expectNotNull(selectFirstNode(cssQuery, `type`), if (parent().isSome()) {
            "No nodes matched the query '${cssQuery}' on element '${this.tagName()}'."
        } else {
            "No nodes matched the query '${cssQuery}' in the document."
        })
    }
    public open func `is`(cssQuery: String): Bool {
        return `is`(Selector.evaluatorOf(cssQuery))
    }
    public open func `is`(evaluator: ?Evaluator): Bool {
        return evaluator.getOrThrow().matches(root(), this)
    }
    public open func closest(cssQuery: String): ?Element {
        return closest(Selector.evaluatorOf(cssQuery))
    }
    public open func closest(evaluator: Evaluator): ?Element {
        var el: ?Element = this
        let root = root()
        do {
            if (evaluator.matches(root, el.getOrThrow())) {
                return el
            }
            el = el.getOrThrow().parent()
        } while (el.isSome())
        return None
    }
    public open func appendChild(child: Node): Element {
        reparentChild(child)
        ensureChildNodes()
        childNodes.add(child)
        child._siblingIndex = childNodes.size - 1
        return this
    }
    public open func appendChildren(children: ArrayList<Node>): Element {
        insertChildren(-1, children)
        return this
    }
    public open func appendTo(parent: Element): Element {
        parent.appendChild(this)
        return this
    }
    public open func prependChild(child: Node): Element {
        addChildren(0, child)
        return this
    }
    public open func prependChildren(children: ArrayList<Node>): Element {
        insertChildren(0, children)
        return this
    }
    public open func insertChildren(index: Int64, children: ArrayList<Node>): Element {
        var calculatedIndex = index
        let currentSize = childNodeSize()
        if (calculatedIndex < 0) {
            calculatedIndex += currentSize + 1
        }
        isTrue((calculatedIndex >= 0) && (calculatedIndex <= currentSize), "Insert position out of bounds.")
        addChildren(calculatedIndex, children.toTypedArray())
        return this
    }
    public open func insertChildren(index: Int64, children: Array<Node>): Element {
        var calculatedIndex = index
        let currentSize = childNodeSize()
        if (calculatedIndex < 0) {
            calculatedIndex += currentSize + 1
        }
        Validate.isTrue(calculatedIndex >= 0 && calculatedIndex <= currentSize, "Insert position out of bounds.")
        addChildren(calculatedIndex, children)
        return this
    }
    public open func appendElement(tagName: String, namespace!: String): Element {
        let parser: Parser = parser(this)
        let child = Element(parser.tagSet().valueOf(tagName, namespace, parser.settings()), baseUri())
        appendChild(child)
        return child
    }
    public open func prependElement(tagName: String, namespace!: String): Element {
        let parser = parser(this)
        let child = Element(parser.tagSet().valueOf(tagName, namespace, parser.settings()), baseUri())
        prependChild(child)
        return child
    }
    public open func appendText(text: String): Element {
        let node = TextNode(text)
        appendChild(node)
        return this
    }
    public open func prependText(text: String): Element {
        let node = TextNode(text)
        prependChild(node)
        return this
    }
    public open func append(html: String): Element {
        let nodes: ArrayList<Node> = parser(this).parseFragmentInput(html, this, baseUri())
        addChildren(nodes.toTypedArray())
        return this
    }
    public open func prepend(html: String): Element {
        let nodes: ArrayList<Node> = parser(this).parseFragmentInput(html, this, baseUri())
        addChildren(0, nodes.toTypedArray())
        return this
    }
    public open override func before(html: String): Element {
        return (super.before(html) as Element)
    }
    public open override func before(node: Node): Element {
        return (super.before(node) as Element)
    }
    public open override func after(html: String): Element {
        return (super.after(html) as Element)
    }
    public open override func after(node: Node): Element {
        return (super.after(node) as Element)
    }
    public open override func empty(): Element {
        let size = childNodes.size
        for (i in 0..size) {
            childNodes[i]._parentNode = None
        }
        childNodes.clear()
        return this
    }
    public open override func wrap(html: String): Element {
        return (super.wrap(html) as Element)
    }
    public open func uniqueIdSelector(ownerDoc: ?Document): String {
        let id = id()
        if (!id.isEmpty()) {
            let idSel = "#" + escapeCssIdentifier(id).toString()
            if (let Some(ownerDocValue) <- ownerDoc) {
                let ownerDoc = ownerDocValue
                let els = ownerDoc.select(idSel)
                if ((els.size == 1) && (els[0] == this)) {
                    return idSel
                }
            } else {
                return idSel
            }
        }
        return EmptyString
    }
    public open func cssSelector(): String {
        let ownerDoc = ownerDocument()
        var idSel = uniqueIdSelector(ownerDoc)
        if (!idSel.isEmpty()) {
            return idSel
        }
        let selector: StringBuilder = StringUtil.borrowBuilder()
        var el: ?Element = this
        while ((el.isSome()) && !(el is Document)) {
            idSel = el.getOrThrow().uniqueIdSelector(ownerDoc)
            if (!idSel.isEmpty()) {
                selector.insert(0, idSel)
                break
            }
            selector.insert(0, el.getOrThrow().cssSelectorComponent())
            el = el.getOrThrow().parent()
        }
        return StringUtil.releaseBuilder(selector)
    }
    public open func cssSelectorComponent(): String {
        let tagName: String = escapeCssIdentifier(tagName()).replace("\\:", "|")
        let selector: StringBuilder = StringUtil.borrowBuilder().append(tagName)
        let escapedClasses: StringUtil.StringJoiner = StringUtil.StringJoiner(".")
        for (name in classNames()) {
            escapedClasses.add(escapeCssIdentifier(name))
        }
        let classes: String = escapedClasses.complete()
        if (!(classes.isEmpty())) {
            selector.append(r'.').append(classes)
        }
        let parent: ?Element = parent()
        if ((parent.isNone()) || (parent is Document)) {
            return StringUtil.releaseBuilder(selector)
        }
        selector.insert(0, " > ")
        if (parent.getOrThrow().select(selector.toString()).size > 1) {
            selector.append(":nth-child(${elementSiblingIndex() + 1})")
        }
        return StringUtil.releaseBuilder(selector)
    }
    public open func siblingElements(): Elements {
        if (_parentNode.isNone()) {
            return Elements()
        }
        let elements = (_parentNode as Element).childElementsList()
        let siblings = Elements()
        for (el in elements) {
            if (el != this) {
                siblings.add(el)
            }
        }
        return siblings
    }
    public open func nextElementSiblings(): Elements {
        return nextElementSiblings(true)
    }
    public open func previousElementSiblings(): Elements {
        return nextElementSiblings(false)
    }
    public open func nextElementSiblings(next: Bool): Elements {
        let els = Elements()
        if (_parentNode.isNone()) {
            return els
        }
        els.add(this)
        return if (next) {
            els.nextAll()
        } else {
            els.prevAll()
        }
    }
    public open func firstElementSibling(): ?Element {
        let parent: ?Element = parent()
        return if (let Some(parentValue) <- parent) {
            let parent = parentValue
            parent.firstElementChild()
        } else {
            this
        }
    }
    public open func elementSiblingIndex(): Int64 {
        let parent: ?Element = parent()
        return if (let Some(parentValue) <- parent) {
            let parent = parentValue
            indexInList(this, parent.childElementsList())
        } else {
            0
        }
    }
    public open func lastElementSibling(): ?Element {
        let parent: ?Element = parent()
        return if (let Some(parentValue) <- parent) {
            let parent = parentValue
            parent.lastElementChild()
        } else {
            this
        }
    }
    public open func firstElementChild(): ?Element {
        let size = childNodes.size
        for (i in 0..size) {
            let node: Node = childNodes[i]
            if ((node is Element)) {
                return node
            }
        }
        return None
    }
    public open func lastElementChild(): ?Element {
        for (i in ({ => let _s = collectArrayList((0..childNodes.size).iterator()); _s.reverse(); _s })()) {
            let node: Node = childNodes[i]
            if ((node is Element)) {
                return node
            }
        }
        return None
    }
    public open func getElementsByTag(tagName: ?String): Elements {
        Validate.notEmpty(tagName)
        let normalizedTagName = normalize(tagName)
        return Collector.collect(Evaluator.Tag(normalizedTagName), this)
    }
    public open func getElementById(id: String): ?Element {
        Validate.notEmpty(id)
        return findFirst(Evaluator.Id(id), this)
    }
    public open func getElementsByClass(className: String): Elements {
        Validate.notEmpty(className)
        return Collector.collect(Evaluator.Class(className), this)
    }
    public open func getElementsByAttribute(key: String): Elements {
        Validate.notEmpty(key)
        let trimmedKey = key.trimAscii({ it => it <= r' ' })
        return Collector.collect(Evaluator.Attribute(trimmedKey), this)
    }
    public open func getElementsByAttributeStarting(keyPrefix: String): Elements {
        Validate.notEmpty(keyPrefix)
        let trimmedKeyPrefix = keyPrefix.trimAscii({ it => it <= r' ' })
        return Collector.collect(Evaluator.AttributeStarting(trimmedKeyPrefix), this)
    }
    public open func getElementsByAttributeValue(key: String, value: String): Elements {
        return Collector.collect(Evaluator.AttributeWithValue(key, value), this)
    }
    public open func getElementsByAttributeValueNot(key: String, value: String): Elements {
        return Collector.collect(Evaluator.AttributeWithValueNot(key, value), this)
    }
    public open func getElementsByAttributeValueStarting(key: String, valuePrefix: String): Elements {
        return Collector.collect(Evaluator.AttributeWithValueStarting(key, valuePrefix), this)
    }
    public open func getElementsByAttributeValueEnding(key: String, valueSuffix: String): Elements {
        return Collector.collect(Evaluator.AttributeWithValueEnding(key, valueSuffix), this)
    }
    public open func getElementsByAttributeValueContaining(key: String, `match`: String): Elements {
        return Collector.collect(Evaluator.AttributeWithValueContaining(key, `match`), this)
    }
    public open func getElementsByAttributeValueMatching(key: String, regex: Regex): Elements {
        return Collector.collect(Evaluator.AttributeWithValueMatching(key, regex), this)
    }
    public open func getElementsByAttributeValueMatching(key: String, regex: String): Elements {
        let pattern: Regex = try {
            jsSupportedRegex(regex)
        } catch (e: PatternSyntaxException) {
            throw IllegalArgumentException("Pattern syntax error: ${regex}", e)
        }
        return Collector.collect(Evaluator.AttributeWithValueMatching(key, pattern), this)
    }
    public open func getElementsByIndexLessThan(index: Int64): Elements {
        return Collector.collect(Evaluator.IndexLessThan(index), this)
    }
    public open func getElementsByIndexGreaterThan(index: Int64): Elements {
        return Collector.collect(Evaluator.IndexGreaterThan(index), this)
    }
    public open func getElementsByIndexEquals(index: Int64): Elements {
        return Collector.collect(Evaluator.IndexEquals(index), this)
    }
    public open func getElementsContainingText(searchText: String): Elements {
        return Collector.collect(Evaluator.ContainsText(searchText), this)
    }
    public open func getElementsContainingOwnText(searchText: String): Elements {
        return Collector.collect(Evaluator.ContainsOwnText(searchText), this)
    }
    public open func getElementsMatchingText(regex: Regex): Elements {
        return Collector.collect(Evaluator.Matches(regex), this)
    }
    public open func getElementsMatchingText(regex: String): Elements {
        let pattern: Regex = try {
            jsSupportedRegex(regex)
        } catch (e: PatternSyntaxException) {
            throw IllegalArgumentException("Pattern syntax error: ${regex}", e)
        }
        return Collector.collect(Evaluator.Matches(pattern), this)
    }
    public open func getElementsMatchingOwnText(regex: Regex): Elements {
        return Collector.collect(Evaluator.MatchesOwn(regex), this)
    }
    public open func getElementsMatchingOwnText(regex: String): Elements {
        let pattern: Regex = try {
            jsSupportedRegex(regex)
        } catch (e: PatternSyntaxException) {
            throw IllegalArgumentException("Pattern syntax error: ${regex}", e)
        }
        return Collector.collect(Evaluator.MatchesOwn(pattern), this)
    }
    public open func getAllElements(): Elements {
        return Collector.collect(Evaluator.AllElements(), this)
    }
    public open func text(): String {
        let accum: StringBuilder = StringUtil.borrowBuilder()
        TextAccumulator(accum).traverse(this)
        return StringUtil.releaseBuilder(accum).trimAscii()
    }
    public open func wholeText(): String {
        return wholeTextOf(nodeStream())
    }
    public open override func nodeValue(): String {
        return wholeOwnText()
    }
    public open func wholeOwnText(): String {
        return wholeTextOf(childNodes().asSequence())
    }
    public open func ownText(): String {
        let sb: StringBuilder = StringUtil.borrowBuilder()
        ownText(sb)
        return StringUtil.releaseBuilder(sb).trimAscii()
    }
    public open func ownText(accum: StringBuilder) {
        for (i in 0..childNodeSize()) {
            let child: Node = childNodes[i]
            if ((child is TextNode)) {
                appendNormalisedText(accum, child)
            } else if (child.nameIs("br") && !lastCharIsWhitespace(accum)) {
                accum.append(" ")
            }
        }
    }
    public open func text(text: String): Element {
        empty()
        if (_tag().`is`(Tag.Data)) {
            appendChild(DataNode(text))
        } else {
            appendChild(TextNode(text))
        }
        return this
    }
    public open func hasText(): Bool {
        let hasText = AtomicBoolean(false)
        filter(object)
        return hasText.get()
    }
    public open func data(): String {
        let sb: StringBuilder = StringUtil.borrowBuilder()
        traverse({ childNode, depth =>
            match (childNode) {
                case childNode: DataNode => sb.append(childNode.getWholeData())
                case childNode: Comment => sb.append(childNode.getData())
                case childNode: CDataNode => sb.append(childNode.getWholeText())
                case _ => throw Exception("")}
        })
        return StringUtil.releaseBuilder(sb)
    }
    public open func className(): String {
        return attr("class").trimAscii()
    }
    public open func classNames(): HashSet<String> {
        let names: ArrayList<String> = Element.ClassSplit().split(className())
        let classNames: HashSet<String> = LinkedHashSet(names)
        classNames.remove("")
        return classNames
    }
    public open func classNames(classNames: HashSet<String>): Element {
        if (classNames.isEmpty()) {
            _attributes().remove("class")
        } else {
            _attributes().put("class", StringUtil.join(classNames, " "))
        }
        return this
    }
    public open func hasClass(className: String): Bool {
        if (_attributes.isNone()) {
            return false
        }
        let classAttr: String = _attributes.getOrThrow().getIgnoreCase("class")
        let len = classAttr.toRuneArray().size
        let wantLen = className.toRuneArray().size
        if ((len == 0) || (len < wantLen)) {
            return false
        }
        if (len == wantLen) {
            return (className.toAsciiLower() == classAttr.toAsciiLower())
        }
        var inClass = false
        var start = 0
        for (i in 0..len) {
            if (classAttr.toRuneArray()[i].isAsciiWhiteSpace()) {
                if (inClass) {
                    if (((i - start) == wantLen) && classAttr.regionMatches(start, className, 0, wantLen, true)) {
                        return true
                    }
                    inClass = false
                }
            } else {
                if (!inClass) {
                    inClass = true
                    start = i
                }
            }
        }
        return if (inClass && ((len - start) == wantLen)) {
            classAttr.regionMatches(start, className, 0, wantLen, true)
        } else {
            false
        }
    }
    public open func addClass(className: String): Element {
        let classes = classNames()
        classes.add(className)
        classNames(classes)
        return this
    }
    public open func removeClass(className: String): Element {
        let classes = classNames()
        classes.remove(className)
        classNames(classes)
        return this
    }
    public open func toggleClass(className: String): Element {
        let classes = classNames()
        if (classes.contains(className)) {
            classes.remove(className)
        } else {
            classes.add(className)
        }
        classNames(classes)
        return this
    }
    public open func value(): String {
        return if (elementIs("textarea", Parser.NamespaceHtml)) {
            text()
        } else {
            attr("value")
        }
    }
    public open func value(value: String): Element {
        if (elementIs("textarea", Parser.NamespaceHtml)) {
            text(value)
        } else {
            attr("value", value)
        }
        return this
    }
    public open func endSourceRange(): Range {
        return Range.of(this, false)
    }
    public open override func outerHtmlHead(accum: QuietAppendable, out: Document.OutputSettings) {
        let tagName = safeTagName(out.syntax())
        accum.append(r'<').append(tagName)
        _attributes?.html(accum, out)
        if (childNodes.isEmpty()) {
            let xmlMode = (out.syntax() == Document.OutputSettings.Syntax.xml) || (_tag.namespace() != Parser.NamespaceHtml)
            if (xmlMode && (_tag.`is`(Tag.SeenSelfClose) || (_tag.isKnownTag() && (_tag.isEmpty() || _tag.isSelfClosing())))) {
                accum.append(" />")
            } else if (!xmlMode && _tag.isEmpty()) {
                accum.append(r'>')
            } else {
                accum.append("></").append(tagName).append(r'>')
            }
        } else {
            accum.append(r'>')
        }
    }
    public open override func outerHtmlTail(accum: QuietAppendable, out: Document.OutputSettings) {
        if (!childNodes.isEmpty()) {
            accum.append("</").append(safeTagName(out.syntax())).append(r'>')
        }
    }
    public open func safeTagName(syntax: Document.OutputSettings.Syntax): ?String {
        return if (syntax == Document.OutputSettings.Syntax.xml) {
            Normalizer.xmlSafeTagName(tagName())
        } else {
            tagName()
        }
    }
    public open func html(): String {
        let sb = StringUtil.borrowBuilder()
        html(sb)
        let html = StringUtil.releaseBuilder(sb)
        return if (outputSettings(this).prettyPrint()) {
            html.trimAscii({ it => it <= r' ' })
        } else {
            html
        }
    }
    public open override func html<T>(appendable: T): T where T <: Appendable {
        var child = firstChild()
        if (child.isSome()) {
            let printer = Printer.printerFor(child, QuietAppendable.wrap(appendable))
            while (child.isSome()) {
                printer.traverse(child)
                child = child.nextSibling()
            }
        }
        return appendable
    }
    public open func html(html: String): Element {
        empty()
        append(html)
        return this
    }
    public open override func createClone(): Node {
        let clone = Element(this.tag, _baseUri)
        clone.attributes = _attributes
        clone.childNodes = childNodes
        return clone
    }
    public open override func clone(): Element {
        return (super.clone() as Element)
    }
    public open override func doClone(parent: ?Node): Element {
        let clone = (super.doClone(parent) as Element)
        clone.childNodes = NodeList(childNodes.size)
        clone.childNodes.add(all: childNodes)
        if (let Some(_attributesValue) <- _attributes) {
            let _attributes = _attributesValue
            clone.attributes = _attributes?.clone()
            clone.attributes.userData(Element.childElsKey, None)
        }
        return clone
    }
    public open override func shallowClone(): Element {
        let baseUri = baseUri().ifEmpty({ => None })
        return Element(_tag, baseUri, _attributes?.clone())
    }
    public open override func clearAttributes(): Element {
        if (_attributes.isSome()) {
            super.clearAttributes()
            if (_attributes.getOrThrow().size == 0) {
                _attributes = None
            }
        }
        return this
    }
    public open override func removeAttr(attributeKey: String): Element {
        return (super.removeAttr(attributeKey) as Element)
    }
    public open override func root(): Element {
        return (super.root() as Element)
    }
    public open override func traverse(nodeVisitor: NodeVisitor): Element {
        return (super.traverse(nodeVisitor) as Element)
    }
    public open override func forEachNode(action: Consumer<Node>): Element {
        return (super.forEachNode(action) as Element)
    }
    public open func forEach(action: (Element) -> Unit) {
        for (_e in stream()) { (action)(_e) }
    }
    public open override func iterator(): Iterator<Element> {
        return NodeIterator<Element>(this, Element)
    }
    public open override func filter(nodeFilter: NodeFilter): Element {
        return (collectArrayList(`super`.iterator().filter(nodeFilter)) as Element)
    }
    public open func reindexChildren() {
        let size: Int64 = childNodes.size
        for (i in 0..size) {
            childNodes[i]._siblingIndex = i
        }
        childNodes.validChildren = true
    }
    public open func invalidateChildren() {
        childNodes.validChildren = false
    }
    public open func hasValidChildren(): Bool {
        return childNodes.validChildren
    }
    static let childElsKey: String = "ksoup.childEls"
    static let childElsMod: String = "ksoup.childElsMod"
    static func EmptyChildren(): ArrayList<Element> {
        return emptyList()
    }
    static func EmptyNodeList(): NodeList {
        return NodeList(0)
    }
    static func ClassSplit(): Regex {
        return Regex("\\s+")
    }
    static func BaseUriKey(): String {
        return Attributes.internalKey("baseUri")
    }
    public static func searchUpForAttribute(start: Element, key: String): ?String {
        var el: ?Element = start
        while (el.isSome()) {
            if (el.getOrThrow().attributes?.hasKey(key) == true) {
                return el.getOrThrow().attributes[key]
            }
            el = el.getOrThrow().parent()
        }
        return None
    }
    public static func indexInList<E>(search: Element, elements: ArrayList<E>): Int64 {
        let size = elements.size
        for (i in 0..size) {
            if (elements[i] == search) {
                return i
            }
        }
        return 0
    }
    public static func wholeTextOf(nodeStream: Sequence<Node>): String {
        return String.join(collectArray<String>(nodeStream.map({ node =>
            if ((node is TextNode)) {
                node.getWholeText()
            } else if (node.nameIs("br")) {
                "\n"
            } else {
                ""
            }
        }).iterator().map({e => e.toString()})), delimiter: "")
    }
    public static func appendNormalisedText(accum: StringBuilder, textNode: TextNode) {
        let text: String = textNode.getWholeText()
        if (preserveWhitespace(textNode._parentNode) || (textNode is CDataNode)) {
            accum.append(text)
        } else {
            StringUtil.appendNormalisedWhitespace(accum, text, lastCharIsWhitespace(accum))
        }
    }
    public static func preserveWhitespace(node: ?Node): Bool {
        if ((node is Element)) {
            var el = (node as ?Element)
            var i = 0
            do {
                if (el.tag.preserveWhitespace()) {
                    return true
                }
                el = el.parent()
                i += 1
            } while ((i < 6) && (el.isSome()))
        }
        return false
    }
}

class TextAccumulator <: NodeVisitor {
    let accum: StringBuilder
    init(accum: StringBuilder) {
        this.accum = accum
    }
    public open override func head(node: Node, depth: Int64) {
        if ((node is TextNode)) {
            appendNormalisedText(accum, node)
        } else if ((node is Element)) {
            if ((!(accum.isEmpty()) && (node.isBlock() || node.nameIs("br"))) && !lastCharIsWhitespace(accum)) {
                accum.append(r' ')
            }
        }
    }
    public open override func tail(node: Node, depth: Int64) {
        if ((node is Element)) {
            let next: ?Node = node.nextSibling()
            if ((!node.tag.isInline() && ((next is TextNode) || ((next is Element) && next.getOrThrow().tag.isInline()))) && !lastCharIsWhitespace(accum)) {
                accum.append(r' ')
            }
        }
    }
}

class NodeList <: MutableList {
    init(initialCapacity: Int64) {
        this.list = ArrayList<Node>([initialCapacity])
    }
    var validChildren: Bool = true
    let list: ArrayList<Node>
    var _modCount = 0
    public open override func iterator(): MutableIterator<Node> {
        return collectArrayList(list).iterator()
    }
    public open override func add(node: Node): Bool {
        _modCount += 1
        return list.add(node)
    }
    public open override func remove(element: Node): Bool {
        let result = list.remove(element)
        if (result) {
            _modCount += 1
        }
        return result
    }
    public open override func addAll(elements: ArrayList<Node>): Bool {
        let result = list.add(all: elements)
        if (result) {
            _modCount += 1
        }
        return result
    }
    public open override func addAll(index: Int64, elements: ArrayList<Node>): Bool {
        let result = list.addAll(index, elements)
        if (result) {
            _modCount += 1
        }
        return result
    }
    public open override func removeAll(elements: ArrayList<Node>): Bool {
        let result = list.removeAll(elements)
        if (result) {
            _modCount += 1
        }
        return result
    }
    public open override func retainAll(elements: ArrayList<Node>): Bool {
        let result = list.retainAll(elements)
        if (result) {
            _modCount += 1
        }
        return result
    }
    let size: Int64
    public open override func isEmpty(): Bool {
        return list.isEmpty()
    }
    public open override func contains(element: Node): Bool {
        return list.contains(element)
    }
    public open override func containsAll(elements: ArrayList<Node>): Bool {
        return list.containsAll(elements)
    }
    public open override func get(index: Int64): Node {
        return list[index]
    }
    public open override func indexOf(element: Node): Int64 {
        return list.indexOf(element)
    }
    public open override func lastIndexOf(element: Node): Int64 {
        return list.lastIndexOf(element)
    }
    public open func modCount(): Int64 {
        return _modCount
    }
    public open func incrementMod() {
        this.modCount += 1
    }
    public open override func clear() {
        _modCount += 1
        list.clear()
    }
    public open override func set(index: Int64, element: Node): Node {
        _modCount += 1
        return list.set(index, element)
    }
    public open override func add(index: Int64, element: Node) {
        _modCount += 1
        list.add(index, element)
    }
    public open override func removeAt(index: Int64): Node {
        _modCount += 1
        return list.remove(at: index)
    }
    public open override func listIterator(): MutableListIterator<Node> {
        return list.listIterator()
    }
    public open override func listIterator(index: Int64): MutableListIterator<Node> {
        return list.listIterator(index)
    }
    public open override func subList(fromIndex: Int64, toIndex: Int64): ArrayList<Node> {
        return list.subList(fromIndex, toIndex)
    }
}
