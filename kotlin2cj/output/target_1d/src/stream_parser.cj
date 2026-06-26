package target_1d

import std.collection.*

class StreamParser {
    let parser: Parser
    init(parser: Parser) {
        this.parser = parser
        treeBuilder.nodeListener(elementIterator)
    }
    let treeBuilder = parser.getTreeBuilder()
    let elementIterator: ElementIterator = ElementIterator()
    var _document: ?Document = None
    var stopped = false
    func parse(input: Reader, baseUri: String): StreamParser {
        close()
        elementIterator.reset()
        treeBuilder.initialiseParse(input, baseUri, parser)
        _document = treeBuilder.doc
        return this
    }
    func parse(html: String, baseUri: String): StreamParser {
        return parse(StringReader(html), baseUri)
    }
    func parseFragment(input: Reader, context: ?Element, baseUri: String): StreamParser {
        parse(input, baseUri)
        treeBuilder.initialiseParseFragment(context)
        return this
    }
    func parseFragment(html: String, context: ?Element, baseUri: String): StreamParser {
        return parseFragment(StringReader(html), context, baseUri)
    }
    func stream(): Sequence<Element> {
        return elementIterator.asSequence()
    }
    func iterator(): MutableIterator<?Element> {
        return elementIterator
    }
    func stop(): StreamParser {
        stopped = true
        return this
    }
    func close() {
        treeBuilder.completeParse()
    }
    func use(receiver: (StreamParser) -> Unit) {
        receiver(this)
        close()
    }
    func document(): Document {
        _document = treeBuilder.doc
        requireNotNull(_document, { => "Must run parse() before calling." })
        return _document.getOrThrow()
    }
    func complete(): Document {
        let doc: Document = _document()
        treeBuilder.runParser()
        return doc
    }
    func completeFragment(): ArrayList<Node> {
        treeBuilder.runParser()
        return treeBuilder.completeParseFragment()
    }
    func selectFirst(query: String): ?Element {
        return selectFirst(Selector.evaluatorOf(query))
    }
    func expectFirst(query: String): Element {
        return Validate.expectNotNull(selectFirst(query), "No elements matched the query '${query}' in the document.")
    }
    func selectFirst(eval: Evaluator): ?Element {
        let doc: Document = _document()
        let first: ?Element = doc.selectFirst(eval)
        if (let Some(firstValue) <- first) {
            let first = firstValue
            return first
        }
        return selectNext(eval)
    }
    func selectNext(query: String): ?Element {
        return selectNext(Selector.evaluatorOf(query))
    }
    func expectNext(query: String): Element {
        return Validate.expectNotNull(selectNext(query), "No elements matched the query '${query}' in the document.")
    }
    func selectNext(eval: Evaluator): ?Element {
        let doc: Document = _document()
        return stream().firstOrNull(eval.asPredicate(doc))
    }
}

class ElementIterator <: MutableIterator & NodeVisitor {
    let emitQueue: LinkedList<Element> = ArrayList()
    var current: ?Element = None
    var _next: ?Element = None
    var _tail: ?Element = None
    func reset() {
        emitQueue.clear()
        _tail = None
        _next = _tail
        current = _next
        stopped = false
    }
    public override func hasNext(): Bool {
        maybeFindNext()
        return _next.isSome()
    }
    public override func next(): Element {
        maybeFindNext()
        if (_next.isNone()) {
            throw NoSuchElementException()
        }
        current = _next
        _next = None
        return current.getOrThrow()
    }
    func maybeFindNext() {
        if (stopped || (_next.isSome())) {
            return
        }
        if (!emitQueue.isEmpty()) {
            _next = emitQueue.remove(at: 0)
            return
        }
        while (treeBuilder.stepParser()) {
            if (!emitQueue.isEmpty()) {
                _next = emitQueue.remove(at: 0)
                return
            }
        }
        stop()
        close()
        if (_tail.isSome()) {
            _next = _tail
            _tail = None
        }
    }
    public override func remove() {
        if (current.isNone()) {
            throw NoSuchElementException()
        }
        current?.remove()
    }
    public override func head(node: Node, depth: Int64) {
        if ((node is Element)) {
            let prev: ?Element = node.previousElementSibling()
            if (let Some(prevValue) <- prev) {
                let prev = prevValue
                emitQueue.add(prev)
            }
        }
    }
    public override func tail(node: Node, depth: Int64) {
        if ((node is Element)) {
            _tail = (node as ?Element)
            let lastChild: ?Element = _tail?.lastElementChild()
            if (let Some(lastChildValue) <- lastChild) {
                let lastChild = lastChildValue
                emitQueue.add(lastChild)
            }
        }
    }
}
