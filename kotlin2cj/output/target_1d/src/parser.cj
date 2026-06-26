package target_1d

import std.collection.*

class Parser <: KCloneable {
    var treeBuilder: TreeBuilder
    var errors: ParseErrorList
    var _settings: ParseSettings
    var _tagSet: ?TagSet = None
    let lock = Synchronizable()
    var maxDepthValue: Int64
    var isTrackPosition: Bool = false
    init(treeBuilder: TreeBuilder) {
        this.treeBuilder = treeBuilder
        this.settings = treeBuilder.defaultSettings()
        this.errors = ParseErrorList.noTracking()
        this.maxDepthValue = treeBuilder.defaultMaxDepth()
    }
    func newInstance(): Parser {
        return Parser(this)
    }
    public override func clone(): Parser {
        return Parser(this)
    }
    init(copy: Parser) {
        treeBuilder = copy.treeBuilder.newInstance()
        errors = ParseErrorList(copy.errors)
        _settings = ParseSettings(copy.settings)
        isTrackPosition = copy.isTrackPosition
        maxDepthValue = copy.maxDepthValue
        _tagSet = TagSet(copy.tagSet())
    }
    func parseInput(input: String, baseUri: String): Document {
        return parseInput(StringReader(input), baseUri)
    }
    func parseInput(reader: Reader, baseUri: String): Document {
        return lock.synchronize({ => treeBuilder.parse(reader, baseUri, this) })
    }
    func parseFragmentInput(fragment: String, context: ?Element, baseUri: String): ArrayList<Node> {
        return parseFragmentInput(StringReader(fragment), context, baseUri)
    }
    func parseFragmentInput(fragment: Reader, context: ?Element, baseUri: String): ArrayList<Node> {
        return lock.synchronize({ => treeBuilder.parseFragment(fragment, context, baseUri, errorList: this) })
    }
    func getTreeBuilder(): TreeBuilder {
        return treeBuilder
    }
    func isTrackErrors(): Bool {
        return errors.maxSize > 0
    }
    func setTrackErrors(maxErrors: Int64): Parser {
        errors = if (maxErrors > 0) {
            ParseErrorList.tracking(maxErrors)
        } else {
            ParseErrorList.noTracking()
        }
        return this
    }
    func getErrors(): ParseErrorList {
        return errors
    }
    func setTrackPosition(trackPosition: Bool): Parser {
        isTrackPosition = trackPosition
        return this
    }
    func settings(settings: ParseSettings): Parser {
        this.settings = settings
        return this
    }
    func settings(): ParseSettings {
        return _settings
    }
    func setMaxDepth(maxDepth: Int64): Parser {
        Validate.isTrue(maxDepth >= 1, "maxDepth must be >= 1")
        this.maxDepthValue = maxDepth
        return this
    }
    func getMaxDepth(): Int64 {
        return maxDepthValue
    }
    func tagSet(tagSet: TagSet): Parser {
        this.tagSet = TagSet(tagSet)
        return this
    }
    func tagSet(): TagSet {
        if (_tagSet.isNone()) {
            _tagSet = treeBuilder.defaultTagSet()
        }
        return _tagSet.getOrThrow()
    }
    func unescape(string: String, inAttribute: Bool): String {
        if ((string.indexOf("&") ?? -1) < 0) {
            return string
        }
        this.treeBuilder.initialiseParse(StringReader(string), "", this)
        let tokeniser = Tokeniser(this.treeBuilder)
        return tokeniser.unescapeEntities(inAttribute)
    }
    func defaultNamespace(): String {
        return getTreeBuilder().defaultNamespace()
    }
    static let NamespaceHtml: String = "http://www.w3.org/1999/xhtml"
    static let NamespaceXml: String = "http://www.w3.org/XML/1998/namespace"
    static let NamespaceMathml: String = "http://www.w3.org/1998/Math/MathML"
    static let NamespaceSvg: String = "http://www.w3.org/2000/svg"
    static func parse(html: String, baseUri: String): Document {
        let treeBuilder: TreeBuilder = HtmlTreeBuilder()
        return treeBuilder.parse(StringReader(html), baseUri, Parser(treeBuilder))
    }
    static func parseFragment(fragmentHtml: String, context: ?Element, baseUri: String, errorList!: ?ParseErrorList = None): ArrayList<Node> {
        let treeBuilder = HtmlTreeBuilder()
        let parser = Parser(treeBuilder)
        if (let Some(errorListValue) <- errorList) {
            let errorList = errorListValue
            parser.errors = errorList
        }
        return treeBuilder.parseFragment(StringReader(fragmentHtml), context, baseUri, errorList: parser)
    }
    static func parseXmlFragment(fragmentXml: String, baseUri: String): ArrayList<Node> {
        let treeBuilder = XmlTreeBuilder()
        return treeBuilder.parseFragment(StringReader(fragmentXml), None, baseUri, errorList: Parser(treeBuilder))
    }
    static func parseBodyFragment(bodyHtml: String, baseUri: String): Document {
        let doc: Document = Document.createShell(baseUri)
        let body: Element = doc.body()
        let nodeList: ArrayList<Node> = parseFragment(bodyHtml, body, baseUri)
        body.appendChildren(nodeList)
        return doc
    }
    static func unescapeEntities(html: String, inAttribute: Bool): String {
        if ((html.indexOf("&") ?? -1) < 0) {
            return html
        }
        return htmlParser().unescape(html, inAttribute)
    }
    static func htmlParser(): Parser {
        return Parser(HtmlTreeBuilder())
    }
    static func xmlParser(): Parser {
        return Parser(XmlTreeBuilder()).setMaxDepth(Int64.Max)
    }
}
