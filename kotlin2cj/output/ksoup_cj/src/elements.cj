package ksoup_cj

import std.collection.*

class Elements <: Nodes {
    init(delegateList!: ArrayList<Element> = ArrayList()) {
        super(delegateList)
    }
    init(element: Element) {
        this()
        add(element)
    }
    init(elements: ArrayList<Element>) {
        this()
        addAll(elements)
    }
    public override func clone(): Elements {
        return Elements(delegateList: collectArrayList(this.iterator().map({ it => it.clone() })))
    }
    public override func asList(): ArrayList<Element> {
        return ArrayList([this])
    }
    func attr(attributeKey: String): String {
        for (element in this) {
            if (element.hasAttr(attributeKey)) {
                return element.attr(attributeKey)
            }
        }
        return ""
    }
    func hasAttr(attributeKey: String): Bool {
        for (element in this) {
            if (element.hasAttr(attributeKey)) {
                return true
            }
        }
        return false
    }
    func eachAttr(attributeKey: String): ArrayList<String> {
        let attrs: ArrayList<String> = ArrayList([size])
        for (element in this) {
            if (element.hasAttr(attributeKey)) {
                attrs.add(element.attr(attributeKey))
            }
        }
        return attrs
    }
    func attr(attributeKey: String, attributeValue: ?String): Elements {
        for (element in this) {
            element.attr(attributeKey, attributeValue)
        }
        return this
    }
    func removeAttr(attributeKey: String): Elements {
        for (element in this) {
            element.removeAttr(attributeKey)
        }
        return this
    }
    func addClass(className: String): Elements {
        for (element in this) {
            element.addClass(className)
        }
        return this
    }
    func removeClass(className: String): Elements {
        for (element in this) {
            element.removeClass(className)
        }
        return this
    }
    func toggleClass(className: String): Elements {
        for (element in this) {
            element.toggleClass(className)
        }
        return this
    }
    func hasClass(className: String): Bool {
        for (element in this) {
            if (element.hasClass(className)) {
                return true
            }
        }
        return false
    }
    func value(): String {
        return if (size > 0) {
            first().getOrThrow().value()
        } else {
            ""
        }
    }
    func value(value: String): Elements {
        for (element in this) {
            element.value(value)
        }
        return this
    }
    func text(): String {
        return (Element.text + String.join(collectArray<String>(this.iterator().map({e => e.toString()})), delimiter: " ") + "")
    }
    func hasText(): Bool {
        return this.iterator().any({ it => it.hasText() })
    }
    func eachText(): ArrayList<String> {
        return collectArrayList(this.mapNotNull({ it =>
            if (it.hasText()) {
                it.text()
            } else {
                None
            }
        }))
    }
    func html(): String {
        return String.join(collectArray<String>(this.iterator().map({ it => it.html() })), delimiter: "\n")
    }
    func tagName(tagName: String): Elements {
        for (element in this) {
            element.tagName(tagName)
        }
        return this
    }
    func html(html: String): Elements {
        for (element in this) {
            element.html(html)
        }
        return this
    }
    func prepend(html: String): Elements {
        for (element in this) {
            element.prepend(html)
        }
        return this
    }
    func append(html: String): Elements {
        for (element in this) {
            element.append(html)
        }
        return this
    }
    public override func before(html: String): Elements {
        super.before(html)
        return this
    }
    public override func after(html: String): Elements {
        super.after(html)
        return this
    }
    public override func wrap(html: String): Elements {
        super.wrap(html)
        return this
    }
    func unwrap(): Elements {
        for (element in this) {
            element.unwrap()
        }
        return this
    }
    func empty(): Elements {
        for (element in this) {
            element.empty()
        }
        return this
    }
    public override func remove(): Elements {
        super.remove()
        return this
    }
    func select(query: String): Elements {
        return Selector.select(query, this)
    }
    func selectFirst(cssQuery: String): ?Element {
        return Selector.selectFirst(cssQuery, this)
    }
    func expectFirst(cssQuery: String): Element {
        return Validate.expectNotNull(Selector.selectFirst(cssQuery, this), "No elements matched the query '${cssQuery}' in the elements.")
    }
    func not(query: String): Elements {
        let out: Elements = Selector.select(query, this)
        return Selector.filterOut(this, out)
    }
    func eq(index: Int64): Elements {
        return if (size > index) {
            Elements(delegateList: get(index))
        } else {
            Elements()
        }
    }
    func `is`(query: String): Bool {
        let eval: Evaluator = Selector.evaluatorOf(query)
        for (e in this) {
            if (e.`is`(eval)) {
                return true
            }
        }
        return false
    }
    func next(): Elements {
        return siblings(query: None, true, false)
    }
    func next(query: ?String): Elements {
        return siblings(query: query, true, false)
    }
    func nextAll(): Elements {
        return siblings(query: None, true, true)
    }
    func nextAll(query: ?String): Elements {
        return siblings(query: query, true, true)
    }
    func prev(): Elements {
        return siblings(query: None, false, false)
    }
    func prev(query: ?String): Elements {
        return siblings(query: query, false, false)
    }
    func prevAll(): Elements {
        return siblings(query: None, false, true)
    }
    func prevAll(query: ?String): Elements {
        return siblings(query: query, false, true)
    }
    func siblings(query: ?String, next: Bool, all: Bool): Elements {
        let els = Elements()
        let eval = if (let Some(it) <- query) {
            Selector.evaluatorOf(it)
        }
        for (e in this) {
            var current = e
            do {
                let sib = if (next) {
                    current.nextElementSibling()
                } else {
                    current.previousElementSibling()
                } ?? break
                if ((eval.isNone()) || sib.`is`(eval)) {
                    els.add(sib)
                }
                current = sib
            } while (all)
        }
        return els
    }
    func parents(): Elements {
        let combo: LinkedHashSet<Element> = linkedSetOf()
        for (e in this) {
            combo.addAll(e.parents())
        }
        return Elements(delegateList: combo)
    }
    public override func first(): ?Element {
        return `super`[0]
    }
    public override func last(): ?Element {
        return `super`[`super`.size - 1]
    }
    func traverse(nodeVisitor: NodeVisitor): Elements {
        NodeTraversor.traverse(nodeVisitor, this)
        return this
    }
    func filter(nodeFilter: NodeFilter): Elements {
        NodeTraversor.filter(nodeFilter, this)
        return this
    }
    func forms(): ArrayList<FormElement> {
        let _forms: ArrayList<FormElement> = ArrayList()
        for (el in this) {
            if ((el is FormElement)) {
                forms.add(el)
            }
        }
        return forms
    }
    func comments(): ArrayList<Comment> {
        return childNodesOfType(Comment)
    }
    func textNodes(): ArrayList<TextNode> {
        return childNodesOfType(TextNode)
    }
    func dataNodes(): ArrayList<DataNode> {
        return childNodesOfType(DataNode)
    }
    // NOTE: inline reified function omitted — not supported by translator
}
