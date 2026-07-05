package target_1g

import std.collection.*
import std.deriving.*

class Document <: Element {
    let namespace: String
    let location: ?String
    var parser: Parser
    init(namespace: String, location: ?String, parser!: Parser = Parser.htmlParser()) {
        super(Tag("#root", namespace), location)
        this.namespace = namespace
        this.location = location
        this.parser = parser
    }
    var _outputSettings = OutputSettings()
    var _quirksMode = QuirksMode.noQuirks
    init(baseUri: ?String) {
        this(Parser.NamespaceHtml)
    }
    func documentType(): ?DocumentType {
        for (node in childNodes) {
            if ((node is DocumentType)) {
                return node
            } else if (!(node is LeafNode)) {
                break
            }
        }
        return None
    }
    func htmlEl(): Element {
        var el: ?Element = firstElementChild()
        while (el.isSome()) {
            if (el.getOrThrow().nameIs("html")) {
                return el
            }
            el = el.getOrThrow().nextElementSibling()
        }
        return appendElement("html")
    }
    func head(): Element {
        let html: Element = htmlEl()
        var el: ?Element = html.firstElementChild()
        while (el.isSome()) {
            if (el.getOrThrow().nameIs("head")) {
                return el
            }
            el = el.getOrThrow().nextElementSibling()
        }
        return html.prependElement("head")
    }
    func headOrNull(): ?Element {
        let html: Element = htmlEl()
        var el: ?Element = html.firstElementChild()
        while (el.isSome()) {
            if (el.getOrThrow().nameIs("head")) {
                return el
            }
            el = el.getOrThrow().nextElementSibling()
        }
        return None
    }
    func body(): Element {
        let html: Element = htmlEl()
        var el: ?Element = html.firstElementChild()
        while (el.isSome()) {
            if (el.getOrThrow().nameIs("body") || el.getOrThrow().nameIs("frameset")) {
                return el
            }
            el = el.getOrThrow().nextElementSibling()
        }
        return html.appendElement("body")
    }
    func forms(): ArrayList<FormElement> {
        return select("form").forms()
    }
    func expectForm(cssQuery: String): ?FormElement {
        let els: Elements = select(cssQuery)
        for (el in els) {
            if ((el is FormElement)) {
                return el
            }
        }
        Validate.fail("No form elements matched the query '${cssQuery}' in the document.")
        return None
    }
    func title(): String {
        let titleEl: ?Element = head().selectFirst(Document.titleEval())
        return if (let Some(titleElValue) <- titleEl) {
            let titleEl = titleElValue
            StringUtil.normaliseWhitespace(titleEl.text()).trimAscii()
        } else {
            ""
        }
    }
    func title(title: String): Unit {
        var titleEl: ?Element = head().selectFirst(Document.titleEval())
        if (titleEl.isNone()) {
            titleEl = head().appendElement("title")
        }
        titleEl.getOrThrow().text(title)
    }
    func createElement(tagName: String): Element {
        return Element(parser.tagSet().valueOf(tagName, parser.defaultNamespace(), ParseSettings.preserveCase), Element.searchUpForAttribute(this, Element.BaseUriKey))
    }
    public override func outerHtml(): String {
        return super.html()
    }
    public override func text(text: String): Element {
        body().text(text)
        return this
    }
    public override func nodeName(): String {
        return "#document"
    }
    func charset(charset: Charset): Unit {
        _outputSettings.charset(charset)
        ensureMetaCharsetElement()
    }
    func charset(): Charset {
        return _outputSettings.charset()
    }
    public override func clone(): Document {
        let clone = (super.clone() as Document)
        clone.outputSettings = this.outputSettings.clone()
        clone.attributes = attributes?.clone()
        return clone
    }
    public override func createClone(): Node {
        let clone = Document(namespace, location)
        clone.outputSettings = _outputSettings
        clone.parser = parser
        clone.attributes = attributes
        clone.childNodes = childNodes
        clone.tag = tag
        clone.setBaseUri(this.baseUri())
        return clone
    }
    public override func shallowClone(): Document {
        let clone = Document(this.tag().namespace(), baseUri(), parser: parser)
        clone.attributes = attributes?.clone()
        clone.outputSettings = _outputSettings.clone()
        return clone
    }
    func ensureMetaCharsetElement() {
        match (_outputSettings().syntax()) {
            case Syntax.html => 
                let metaCharset = selectFirst("meta[charset]")
                if (let Some(metaCharsetValue) <- metaCharset) {
                    let metaCharset = metaCharsetValue
                    metaCharset.attr("charset", charset().name())
                } else {
                    head().appendElement("meta").attr("charset", charset().name())
                }
                select("meta[name=charset]").remove()
            case Syntax.xml => 
                { =>
                    let _also_it = ensureXmlDecl()
                    let it = _also_it
                    attr("version", "1.0")
                    attr("encoding", charset().name())
                    return _also_it
                }()
            case _ => ()}
    }
    func ensureXmlDecl(): XmlDeclaration {
        let node = firstChild()
        if ((node is XmlDeclaration) && (node.name() == "xml")) {
            return node
        }
        let decl = XmlDeclaration("xml", false)
        prependChild(decl)
        return decl
    }
    func outputSettings(): OutputSettings {
        return _outputSettings
    }
    func outputSettings(outputSettings: OutputSettings): Document {
        this.outputSettings = outputSettings
        return this
    }
    func quirksMode(): QuirksMode {
        return _quirksMode
    }
    func quirksMode(quirksMode: QuirksMode): Document {
        this.quirksMode = quirksMode
        return this
    }
    func parser(parser: Parser): Document {
        this.parser = parser
        return this
    }
    static func createShell(baseUri: String): Document {
        let doc = Document(baseUri)
        let html: Element = doc.appendElement("html")
        html.appendElement("head")
        html.appendElement("body")
        return doc
    }
    static func titleEval(): Evaluator {
        return Evaluator.Tag("title")
    }
}

class OutputSettings <: KCloneable {
    var escapeMode: Entities.EscapeMode
    var charset: Charset
    var prettyPrint: Bool
    var outline: Bool
    var indentAmount: Int64
    var maxPaddingWidth: Int64
    var syntax: Syntax
    init(escapeMode!: Entities.EscapeMode = Entities.EscapeMode.base, charset!: Charset = Charsets.UTF8, prettyPrint!: Bool = true, outline!: Bool = false, indentAmount!: Int64 = 1, maxPaddingWidth!: Int64 = 30, syntax!: Syntax = Syntax.html) {
        this.escapeMode = escapeMode
        this.charset = charset
        this.prettyPrint = prettyPrint
        this.outline = outline
        this.indentAmount = indentAmount
        this.maxPaddingWidth = maxPaddingWidth
        this.syntax = syntax
    }
    func escapeMode(escapeMode: Entities.EscapeMode): OutputSettings {
        this.escapeMode = escapeMode
        return this
    }
    func charset(charset: Charset): OutputSettings {
        this.charset = charset
        return this
    }
    func charset(charset: String): OutputSettings {
        charset(Charsets.forName(charset))
        return this
    }
    func syntax(syntax: Syntax): OutputSettings {
        this.syntax = syntax
        if (syntax == Syntax.xml) {
            this.escapeMode(Entities.EscapeMode.xhtml)
        }
        return this
    }
    func prettyPrint(pretty: Bool): OutputSettings {
        prettyPrint = pretty
        return this
    }
    func outline(outlineMode: Bool): OutputSettings {
        outline = outlineMode
        return this
    }
    func indentAmount(indentAmount: Int64): OutputSettings {
        Validate.isTrue(indentAmount >= 0)
        this.indentAmount = indentAmount
        return this
    }
    func maxPaddingWidth(maxPaddingWidth: Int64): OutputSettings {
        Validate.isTrue(maxPaddingWidth >= -1)
        this.maxPaddingWidth = maxPaddingWidth
        return this
    }
    public override func clone(): OutputSettings {
        return this.copy()
    }
}

@Derive[Hashable, Equatable]
enum Syntax <: ToString {
    | html | xml
    public func toString(): String {
    return match (this) {
                case html => "html"
            case xml => "xml"
}
    }
}

@Derive[Hashable, Equatable]
enum QuirksMode <: ToString {
    | noQuirks | quirks | limitedQuirks
    public func toString(): String {
    return match (this) {
                case noQuirks => "noQuirks"
            case quirks => "quirks"
            case limitedQuirks => "limitedQuirks"
}
    }
}
