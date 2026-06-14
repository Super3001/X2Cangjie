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

open class XmlTreeBuilder <: TreeBuilder {
    let namespacesStack: ArrayDeque<HashMap<String, String>> = ArrayDeque<HashMap<String, String>>()
    public open override func defaultSettings(): ParseSettings {
        return ParseSettings.preserveCase
    }
    public open override func initialiseParse(input: Reader, baseUri: String, parser: Parser) {
        super.initialiseParse(input, baseUri, parser)
        doc.outputSettings().syntax(OutputSettings.Syntax.xml).escapeMode(EscapeMode.xhtml).prettyPrint(false)
        namespacesStack.clear()
        let ns = HashMap<String, String>()
        ns["xml"] = NamespaceXml
        ns[""] = NamespaceXml
        namespacesStack.add(ns)
    }
    public open override func initialiseParseFragment(context: ?Element) {
        super.initialiseParseFragment(context)
        if (context.isNone()) {
            return
        }
        let textState: ?TokeniserState = context.getOrThrow().tag().textState()
        if (let Some(textStateValue) <- textState) {
            let textState = textStateValue
            tokeniser?.transition(textState)
        }
        let chain = context.getOrThrow().parents()
        chain.add(0, context)
        for (i in (chain.size - 1)..=0 : -1) {
            let el = chain[i]
            let namespaces = HashMap([namespacesStack[0]])
            namespacesStack.addFirst(namespaces)
            if (el.attributesSize() > 0) {
                processNamespaces(el.attributes(), namespaces)
            }
        }
    }
    public open override func completeParseFragment(): ArrayList<Node> {
        return doc.childNodes()
    }
    public open func parse(input: Reader, baseUri: ?String): Document {
        return parse(input, baseUri: baseUri ?? "", Parser(this))
    }
    public open func parse(input: String, baseUri: ?String): Document {
        return parse(StringReader(input), baseUri: baseUri ?? "", Parser(this))
    }
    public open override func newInstance(): XmlTreeBuilder {
        return XmlTreeBuilder()
    }
    public open override func defaultNamespace(): String {
        return NamespaceXml
    }
    public open override func defaultTagSet(): TagSet {
        return TagSet()
    }
    public open override func defaultMaxDepth(): Int64 {
        return Int64.Max
    }
    public open override func process(token: Token): Bool {
        currentToken = token
        match (token.`type`) {
            case Token.TokenType.StartTag => insertElementFor(token.asStartTag())
            case Token.TokenType.EndTag => popStackToClose(token.asEndTag())
            case Token.TokenType.Comment => insertCommentFor(token.asComment())
            case Token.TokenType.Character => insertCharacterFor(token.asCharacter())
            case Token.TokenType.Doctype => insertDoctypeFor(token.asDoctype())
            case Token.TokenType.XmlDecl => insertXmlDeclarationFor(token.asXmlDecl())
            case Token.TokenType.EOF => ()
            case _ => ()}
        return true
    }
    public open func insertElementFor(startTag: Token.StartTag) {
        let namespaces = HashMap([namespacesStack.firstOrNull() ?? HashMap()])
        namespacesStack.addFirst(namespaces)
        let attributes = startTag.attributes
        if (let Some(attributesValue) <- attributes) {
            let attributes = attributesValue
            settings.normalizeAttributes(attributes)
            attributes.deduplicate(settings)
            processNamespaces(attributes, namespaces)
            applyNamespacesToAttributes(attributes, namespaces)
        }
        enforceStackDepthLimit()
        let tagName = startTag.tagName.value()
        let ns = resolveNamespace(tagName, namespaces)
        let tag = tagFor(tagName, startTag.normalName, ns, settings)
        let el = Element(tag, None, attributes)
        currentElement().appendChild(el)
        push(el)
        if (startTag.selfClosing) {
            tag.setSeenSelfClose()
            pop()
        } else if (tag.isEmpty()) {
            pop()
        } else {
            let textState = tag.textState()
            if (let Some(textStateValue) <- textState) {
                let textState = textStateValue
                tokeniser?.transition(textState)
            }
        }
    }
    public open func insertLeafNode(node: ?LeafNode) {
        currentElement().appendChild(node.getOrThrow())
        onNodeInserted(node)
    }
    public open func insertCommentFor(commentToken: Token.Comment) {
        let comment = Comment(commentToken.getData())
        insertLeafNode(comment)
    }
    public open func insertCharacterFor(token: Token.Character) {
        let data: String = token.getData()
        let node = if (token.isCData()) {
            CDataNode(data)
        } else if (currentElement().tag().`is`(Tag.Data)) {
            DataNode(data)
        } else {
            TextNode(data)
        }
        insertLeafNode(node)
    }
    public open func insertDoctypeFor(token: Token.Doctype) {
        let doctypeNode = DocumentType(settings.normalizeTag(token.getName()), token.getPublicIdentifier(), token.getSystemIdentifier())
        doctypeNode.setPubSysKey(token.pubSysKey)
        insertLeafNode(doctypeNode)
    }
    public open func insertXmlDeclarationFor(token: Token.XmlDecl) {
        let decl = XmlDeclaration(token.name(), token.isDeclaration)
        if (let Some(it) <- token.attributes) {
            decl.attributes().add(all: it)
        }
        insertLeafNode(decl)
    }
    public open override func pop(): ?Element {
        namespacesStack.remove(at: 0)
        return super.pop()
    }
    public open func popStackToClose(endTag: TokenEndTag) {
        let elName = settings.normalizeTag(endTag.name())
        var firstFound: ?Element = None
        let bottom: Int64 = getStack().size - 1
        let upper = if (bottom >= XmlTreeBuilder.maxQueueDepth) {
            bottom - XmlTreeBuilder.maxQueueDepth
        } else {
            0
        }
        for (pos in (getStack().size - 1)..=upper : -1) {
            let next = getStack()[pos]
            if (next.nodeName() == elName) {
                firstFound = next
                break
            }
        }
        if (firstFound.isNone()) {
            return
        }
        for (pos in (getStack().size - 1)..=0 : -1) {
            let next = pop()
            if (next == firstFound) {
                break
            }
        }
    }
    static let maxQueueDepth = 256
    static let XmlnsKey: String = "xmlns"
    static let XmlnsPrefix: String = "xmlns:"
    public static func processNamespaces(attributes: Attributes, namespaces: HashMap<String, String>) {
        for (attr in attributes) {
            let key: String = attr.key
            let value: String = attr.value
            if (key == XmlTreeBuilder.XmlnsKey) {
                namespaces.put("", value)
            } else if (key.startsWith(XmlTreeBuilder.XmlnsPrefix)) {
                let nsPrefix = __k2cjRuneSlice(key, XmlTreeBuilder.XmlnsPrefix.toRuneArray().size, key.toRuneArray().size)
                namespaces.put(nsPrefix, value)
            }
        }
    }
    public static func applyNamespacesToAttributes(attributes: Attributes, namespaces: HashMap<String, String>) {
        let attrPrefix: HashMap<String, String> = HashMap()
        for (attr in attributes) {
            let prefix = attr.prefix()
            if (!prefix.isEmpty()) {
                if (prefix == XmlTreeBuilder.XmlnsKey) {
                    continue
                }
                let ns = namespaces[prefix]
                if (let Some(nsValue) <- ns) {
                    let ns = nsValue
                    attrPrefix.put(SharedConstants.XmlnsAttr + prefix, ns)
                }
            }
        }
        for (entry in attrPrefix.entries) {
            attributes.userData(entry.key, entry.value)
        }
    }
    public static func resolveNamespace(tagName: String, namespaces: HashMap<String, String>): ?String {
        var ns = namespaces[""]
        let pos = (tagName.indexOf(":") ?? -1)
        if (pos > 0) {
            let prefix = __k2cjRuneSlice(tagName, 0, pos)
            if (namespaces.contains(prefix)) {
                ns = namespaces[prefix]
            }
        }
        return ns
    }
}
