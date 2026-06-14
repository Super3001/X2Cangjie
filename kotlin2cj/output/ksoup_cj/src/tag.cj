package ksoup_cj

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

class Tag <: KCloneable & ToString {
    var tagName: String
    var _normalName: String
    var _namespace: String
    init(tagName: String, normalName: String, namespace: String) {
        this.tagName = tagName
        this._normalName = normalName
        this._namespace = namespace
    }
    var options: Int64 = 0
    init(tagName: String) {
        this(tagName, ParseSettings.normalName(tagName), Parser.NamespaceHtml)
    }
    init(tagName: String, namespace: String) {
        this(tagName, ParseSettings.normalName(tagName), namespace)
    }
    func name(): String {
        return tagName
    }
    public override func hashCode(): Int64 {
        return [tagName, namespace].contentHashCode()
    }
    func name(tagName: String): Tag {
        this.tagName = tagName
        this._normalName = ParseSettings.normalName(tagName)
        return this
    }
    func prefix(): String {
        let pos = (tagName.indexOf(":") ?? -1)
        return if (pos == -1) {
            ""
        } else {
            __k2cjRuneSlice(tagName, 0, pos)
        }
    }
    func localName(): String {
        let pos = (tagName.indexOf(":") ?? -1)
        return if (pos == -1) {
            tagName
        } else {
            __k2cjRuneSlice(tagName, pos + 1, tagName.toRuneArray().size)
        }
    }
    func isBlock(): Bool {
        return (options & Tag.Block()) != 0
    }
    func isEmpty(): Bool {
        return (options & Tag.Void()) != 0
    }
    func isFormSubmittable(): Bool {
        return (options & Tag.FormSubmittable()) != 0
    }
    func setSeenSelfClose() {
        options = options | Tag.SeenSelfClose()
    }
    func textState(): ?TokeniserState {
        return if (`is`(Tag.RcData())) {
            TokeniserState.Rcdata
        } else if (`is`(Tag.Data())) {
            TokeniserState.Rawtext
        } else {
            None
        }
    }
    func normalName(): String {
        return _normalName
    }
    func namespace(): String {
        return _namespace
    }
    func namespace(namespace: String): Tag {
        this._namespace = namespace
        return this
    }
    func set(option: Int64): Tag {
        options = options | option
        options = options | Tag.Known
        return this
    }
    func `is`(option: Int64): Bool {
        return (options & option) != 0
    }
    func clear(option: Int64): Tag {
        options = options & option.inv()
        if (option != Tag.Known) {
            options = options | Tag.Known
        }
        return this
    }
    func formatAsBlock(): Bool {
        return (options & Tag.InlineContainer()) != 0
    }
    func isInline(): Bool {
        return (options & Tag.Block()) == 0
    }
    func isSelfClosing(): Bool {
        return ((options & Tag.SelfClose()) != 0) || ((options & Tag.Void()) != 0)
    }
    func isKnownTag(): Bool {
        return (options & Tag.Known) != 0
    }
    func preserveWhitespace(): Bool {
        return (options & Tag.PreserveWhitespace()) != 0
    }
    public override func toString(): String {
        return tagName
    }
    public override func clone(): Tag {
        let _clone = this.copy()
        clone.options = this.options
        return _clone
    }
    static let Known = 1
    static let Void = 1 << 1
    static let Block = 1 << 2
    static let InlineContainer = 1 << 3
    static let SelfClose = 1 << 4
    static let SeenSelfClose = 1 << 5
    static let PreserveWhitespace = 1 << 6
    static let RcData = 1 << 7
    static let Data = 1 << 8
    static let FormSubmittable = 1 << 9
    static func valueOf(tagName: String, namespace!: String = Parser.NamespaceHtml, settings!: ParseSettings = ParseSettings.preserveCase): Tag {
        return TagSet.Html().valueOf(tagName, namespace: None, settings: namespace, settings.preserveTagCase())
    }
    static func valueOf(tagName: String, settings: ParseSettings): Tag {
        return valueOf(tagName, namespace: Parser.NamespaceHtml, settings: settings)
    }
    static func isKnownTag(tagName: String): Bool {
        return TagSet.HtmlTagSet.get(tagName, Parser.NamespaceHtml).isSome()
    }
    public override func equals(other: ?Object): Bool {
        if (this == other) {
            return true
        }
        if ((other.isNone()) || (this != other)) {
            return false
        }
        (other as Tag)
        if (options != other.getOrThrow().options) {
            return false
        }
        if (tagName != other.getOrThrow().tagName) {
            return false
        }
        if (normalName != other.getOrThrow().normalName) {
            return false
        }
        if (namespace != other.getOrThrow().namespace) {
            return false
        }
        return true
    }
}
