package target_1d

import std.collection.*

abstract class TreeBuilder {
    var parser: Parser
    var reader: CharacterReader
    var tokeniser: ?Tokeniser = None
    var doc: Document
    var _stack: ?ArrayList<?Element> = None
    var baseUri: String
    var currentToken: Token
    var settings: ParseSettings
    var tagSet: TagSet
    var _nodeListener: ?NodeVisitor = None
    var start: Token.StartTag
    var end: Token.EndTag
    public func defaultSettings(): ParseSettings
    var trackSourceRange: Bool = false
    public open func getStack() {
        return _stack.getOrThrow()
    }
    public open func initialiseParse(input: Reader, baseUri: String, parser: Parser) {
        end = EndTag(this)
        doc = Document(parser.defaultNamespace(), baseUri)
        doc.parser(parser)
        this.parser = parser
        settings = parser.settings()
        reader = CharacterReader(input)
        trackSourceRange = parser.isTrackPosition
        reader.trackNewlines(parser.isTrackErrors() || trackSourceRange)
        if (parser.isTrackErrors()) {
            parser.getErrors().clear()
        }
        tokeniser = Tokeniser(this)
        _stack = ArrayList([32])
        tagSet = parser.tagSet()
        start = StartTag(this)
        currentToken = start
        this.baseUri = baseUri
        onNodeInserted(doc)
    }
    public open func completeParse() {
        if (!(reader.isInitialized)) {
            return
        }
        reader.close()
        tokeniser = None
        _stack = None
    }
    public open func parse(input: Reader, baseUri: String, parser: Parser): Document {
        initialiseParse(input, baseUri, parser)
        runParser()
        return doc
    }
    public open func parseFragment(inputFragment: Reader, context: ?Element, baseUri: String, parser: Parser): ArrayList<Node> {
        initialiseParse(inputFragment, baseUri, parser)
        initialiseParseFragment(context)
        runParser()
        return completeParseFragment()
    }
    public open func initialiseParseFragment(context: ?Element) {}
    public func completeParseFragment(): ArrayList<Node>
    public open func nodeListener(nodeListener: ?NodeVisitor): Unit {
        this.nodeListener = nodeListener
    }
    public func newInstance(): TreeBuilder
    public open func runParser() {
        do {} while (stepParser())
        completeParse()
    }
    public open func stepParser(): Bool {
        if (currentToken.`type` == TokenType.EOF) {
            if (_stack.isNone()) {
                return false
            } else if (_stack?.isEmpty() == true) {
                onNodeClosed(doc)
                _stack = None
                return true
            }
            pop()
            return true
        }
        let token = tokeniser.getOrThrow().read()
        currentToken = token
        process(token)
        token.reset()
        return true
    }
    public func process(token: Token): Bool
    public open func processStartTag(name: String): Bool {
        let start = this.start
        if (currentToken == start) {
            return process(StartTag(this).name(name))
        }
        return process(start.reset().name(name))
    }
    public open func processStartTag(name: String, attrs: ?Attributes): Bool {
        let start = this.start
        if (currentToken == start) {
            return process(StartTag(this).nameAttr(name, attrs))
        }
        start.reset()
        start.nameAttr(name, attrs)
        return process(start)
    }
    public open func processEndTag(name: String): Bool {
        if (currentToken == end) {
            return process(EndTag(this).name(name))
        }
        return process(end.reset().name(name))
    }
    public open func pop(): ?Element {
        let size = _stack?.size
        let removed = if (let Some(sizeValue) <- size) {
            let size = sizeValue
            _stack.remove(at: size - 1)
        } else {
            None
        }
        if (let Some(it) <- removed) {
            onNodeClosed(it)
        }
        return removed
    }
    public open func push(element: Element) {
        getStack().add(element)
        onNodeInserted(element)
    }
    public open func enforceStackDepthLimit() {
        let maxDepth: Int64 = parser.getMaxDepth()
        if (maxDepth == Int.Companion.MAX_VALUE) {
            return
        }
        while (_stack.getOrThrow().size >= maxDepth) {
            let trimmed = pop()
            if (let Some(it) <- trimmed) {
                onStackPrunedForDepth(it)
            }
        }
    }
    public open func onStackPrunedForDepth(element: Element) {}
    public open func defaultMaxDepth(): Int64 {
        return 512
    }
    public open func currentElement(): Element {
        let size: Int64 = _stack?.size ?? 0
        return if (size > 0) {
            _stack.getOrThrow()[size - 1]
        } else {
            doc
        }
    }
    public open func currentElementIs(normalName: ?String): Bool {
        if ((_stack?.size ?? 0) == 0) {
            return false
        }
        let current: Element = currentElement()
        return (current.normalName() == normalName) && (current.tag().namespace() == NamespaceHtml)
    }
    public open func currentElementIs(normalName: ?String, namespace: ?String): Bool {
        if ((_stack?.size ?? 0) == 0) {
            return false
        }
        let current: Element = currentElement()
        return (current.normalName() == normalName) && (current.tag().namespace() == namespace)
    }
    public open func error(msg: String) {
        let errors: ParseErrorList = parser.getErrors()
        if (errors.canAddError()) {
            errors.add(ParseError(reader, msg))
        }
    }
    public open func tagFor(tagName: String, normalName: String, namespace: String, settings: ParseSettings): Tag {
        return tagSet.valueOf(tagName, namespace: normalName, settings: namespace, settings.preserveTagCase())
    }
    public open func tagFor(token: TokenTag): Tag {
        return tagSet.valueOf(token.name(), namespace: token.normalName, settings: defaultNamespace(), settings.preserveTagCase())
    }
    public open func defaultNamespace(): String {
        return NamespaceHtml
    }
    public open func defaultTagSet(): TagSet {
        return TagSet.Html()
    }
    public open func onNodeInserted(node: Node) {
        trackNodePosition(node, true)
        _nodeListener?.head(node, getStack().size)
    }
    public open func onNodeClosed(node: Node) {
        trackNodePosition(node, false)
        _nodeListener?.tail(node, _stack.getOrThrow().size)
    }
    public open func trackNodePosition(node: Node, isStart: Bool) {
        if (!trackSourceRange) {
            return
        }
        let token = currentToken
        var startPos = token.startPos()
        var endPos = token.endPos()
        if ((node is Element)) {
            if (token.isEOF()) {
                if (node.endSourceRange().isTracked()) {
                    return
                }
                endPos = reader.pos()
                startPos = endPos
            } else if (isStart) {
                if (!token.isStartTag() || (node.normalName() != token.asStartTag().normalName)) {
                    endPos = startPos
                }
            } else {
                if (!node.tag().isEmpty() && !node.tag().isSelfClosing()) {
                    if (!token.isEndTag() || (node.normalName() != token.asEndTag().normalName)) {
                        endPos = startPos
                    }
                }
            }
        }
        let startPosition: Range.Position = Range.Position(startPos, reader.lineNumber(startPos), reader.columnNumber(startPos))
        let endPosition: Range.Position = Range.Position(endPos, reader.lineNumber(endPos), reader.columnNumber(endPos))
        let range = Range(startPosition, endPosition)
        node.attributes().userData(if (isStart) {
            SharedConstants.RangeKey
        } else {
            SharedConstants.EndRangeKey
        }, range)
    }
}
