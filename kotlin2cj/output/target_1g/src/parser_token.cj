package target_1g

import std.deriving.*

abstract class Token {
    var `type`: TokenType
    init(`type`: TokenType) {
        this.`type` = `type`
    }
    var _startPos = 0
    var _endPos = Token.UnsetPos()
    public open func tokenType(): String {
        return this.simpleName ?? "Token"
    }
    public open func reset(): Token {
        _startPos = Token.UnsetPos()
        _endPos = Token.UnsetPos()
        return this
    }
    public open func startPos(): Int64 {
        return _startPos
    }
    public open func startPos(pos: Int64) {
        _startPos = pos
    }
    public open func endPos(): Int64 {
        return _endPos
    }
    public open func endPos(pos: Int64) {
        _endPos = pos
    }
    public open func isDoctype(): Bool {
        return `type` == TokenType.Doctype
    }
    public open func asDoctype(): Doctype {
        return (this as Doctype)
    }
    public open func isStartTag(): Bool {
        return `type` == TokenType.StartTag
    }
    public open func asStartTag(): StartTag {
        return (this as StartTag)
    }
    public open func isEndTag(): Bool {
        return `type` == TokenType.EndTag
    }
    public open func asEndTag(): EndTag {
        return (this as EndTag)
    }
    public open func isComment(): Bool {
        return `type` == TokenType.Comment
    }
    public open func asComment(): Comment {
        return (this as Comment)
    }
    public open func isCharacter(): Bool {
        return `type` == TokenType.Character
    }
    public open func isCData(): Bool {
        return (this is CData)
    }
    public open func asCharacter(): Character {
        return (this as Character)
    }
    public open func asXmlDecl(): XmlDecl {
        return (this as XmlDecl)
    }
    public open func isEOF(): Bool {
        return `type` == TokenType.EOF
    }
    static func UnsetPos(): Int64 {
        return -1
    }
    public static func reset(sb: ?StringBuilder) {
        sb.clear()
    }
}

class Doctype <: Token & ToString {
    init() {
        super(TokenType.Doctype)
    }
    let name: TokenData = TokenData()
    var pubSysKey: ?String = None
    let publicIdentifier: TokenData = TokenData()
    let systemIdentifier: TokenData = TokenData()
    var forceQuirks: Bool = false
    public open override func reset(): Token {
        super.reset()
        name.reset()
        pubSysKey = None
        publicIdentifier.reset()
        systemIdentifier.reset()
        forceQuirks = false
        return this
    }
    public open func getName(): String {
        return name.value()
    }
    public open func getPublicIdentifier(): String {
        return publicIdentifier.value()
    }
    public open func getSystemIdentifier(): String {
        return systemIdentifier.value()
    }
    public open override func toString(): String {
        return "<!doctype ${getName()}>"
    }
}

abstract class Tag <: Token & ToString {
    let treeBuilder: TreeBuilder
    init(`type`: TokenType, treeBuilder: TreeBuilder) {
        super(`type`)
        this.treeBuilder = treeBuilder
    }
    var tagName: TokenData = TokenData()
    var normalName: ?String = None
    var selfClosing: Bool = false
    var attributes: ?Attributes = None
    let attrName = TokenData()
    let attrValue = TokenData()
    var hasEmptyAttrValue = false
    let trackSource: Bool = treeBuilder.trackSourceRange
    var attrNameStart: Int64 = 0
    var attrNameEnd: Int64 = 0
    var attrValStart: Int64 = 0
    var attrValEnd: Int64 = 0
    public open override func reset(): Tag {
        super.reset()
        tagName.reset()
        normalName = None
        selfClosing = false
        attributes = None
        resetPendingAttr()
        return this
    }
    public open func resetPendingAttr() {
        attrName.reset()
        attrValue.reset()
        hasEmptyAttrValue = false
        if (trackSource) {
            attrValEnd = UnsetPos
            attrValStart = attrValEnd
            attrNameEnd = attrValStart
            attrNameStart = attrNameEnd
        }
    }
    public open func newAttribute() {
        if (attributes.isNone()) {
            attributes = Attributes()
        }
        if (attrName.hasData() && (attributes.getOrThrow().size() < Tag.MaxAttributes)) {
            var name = attrName.value()
            name = name.trimAscii({ it => it <= r' ' })
            if (!name.isEmpty()) {
                let value: ?String
                if (attrValue.hasData()) {
                    value = attrValue.value()
                } else if (hasEmptyAttrValue) {
                    value = ""
                } else {
                    value = None
                }
                attributes.getOrThrow().add(name, value)
                trackAttributeRange(name)
            }
        }
        resetPendingAttr()
    }
    public open func trackAttributeRange(name: String) {
        if (trackSource && isStartTag()) {
            let start = asStartTag()
            let r = start.treeBuilder.reader
            let preserve = start.treeBuilder.settings.preserveAttributeCase()
            var name = name
            if (!preserve) {
                name = Normalizer.lowerCase(name)
            }
            if (attributes.getOrThrow().sourceRange(name).nameRange().isTracked()) {
                return
            }
            if (!attrValue.hasData()) {
                attrValEnd = attrNameEnd
                attrValStart = attrValEnd
            }
            let range: Range.AttributeRange = Range.AttributeRange(Range(Range.Position(attrNameStart, r.lineNumber(attrNameStart), r.columnNumber(attrNameStart)), Range.Position(attrNameEnd, r.lineNumber(attrNameEnd), r.columnNumber(attrNameEnd))), Range(Range.Position(attrValStart, r.lineNumber(attrValStart), r.columnNumber(attrValStart)), Range.Position(attrValEnd, r.lineNumber(attrValEnd), r.columnNumber(attrValEnd))))
            attributes.getOrThrow().sourceRange(name, range)
        }
    }
    public open func hasAttributes(): Bool {
        return attributes.isSome()
    }
    public open func hasAttributeIgnoreCase(key: ?String): Bool {
        return (attributes.isSome()) && attributes.getOrThrow().hasKeyIgnoreCase(key.getOrThrow())
    }
    public open func finaliseTag() {
        if (attrName.hasData()) {
            newAttribute()
        }
    }
    public open func name(): String {
        return tagName.value()
    }
    public open func retrieveNormalName(): String {
        Validate.isFalse((normalName.isNone()) || normalName.getOrThrow().isEmpty())
        return normalName ?? ""
    }
    public open func toStringName(): String {
        let name = tagName.value()
        return name.ifEmpty({ => "[unset]" })
    }
    public open func name(name: String): Tag {
        tagName.set(name)
        normalName = ParseSettings.normalName(tagName.value())
        return this
    }
    public open func appendTagName(append: String) {
        let append = append.replace(TokeniserState.nullChar, Tokeniser.ReplacementChar)
        tagName.append(append)
        normalName = ParseSettings.normalName(tagName.value())
    }
    public open func appendTagName(append: Rune): Unit {
        appendTagName(append.toString())
    }
    public open func appendAttributeName(append: String, startPos: Int64, endPos: Int64) {
        let append = append.replace(TokeniserState.nullChar, Tokeniser.ReplacementChar)
        attrName.append(append)
        attrNamePos(startPos, endPos)
    }
    public open func appendAttributeName(append: Rune, startPos: Int64, endPos: Int64) {
        attrName.append(append)
        attrNamePos(startPos, endPos)
    }
    public open func appendAttributeValue(append: String, startPos: Int64, endPos: Int64) {
        attrValue.append(append)
        attrValPos(startPos, endPos)
    }
    public open func appendAttributeValue(append: Rune, startPos: Int64, endPos: Int64) {
        attrValue.append(append)
        attrValPos(startPos, endPos)
    }
    public open func appendAttributeValue(appendCodepoints: IntArray, startPos: Int64, endPos: Int64) {
        for (codepoint in appendCodepoints) {
            attrValue.appendCodePoint(codepoint)
        }
        attrValPos(startPos, endPos)
    }
    public open func setEmptyAttributeValue() {
        hasEmptyAttrValue = true
    }
    public open func attrNamePos(startPos: Int64, endPos: Int64) {
        if (trackSource) {
            attrNameStart = if (attrNameStart > UnsetPos) {
                attrNameStart
            } else {
                startPos
            }
            attrNameEnd = endPos
        }
    }
    public open func attrValPos(startPos: Int64, endPos: Int64) {
        if (trackSource) {
            attrValStart = if (attrValStart > UnsetPos) {
                attrValStart
            } else {
                startPos
            }
            attrValEnd = endPos
        }
    }
    public func toString(): String
    static let MaxAttributes = 512
}

class StartTag <: Tag & ToString {
    init(treeBuilder: TreeBuilder) {
        super(TokenType.StartTag, treeBuilder)
    }
    public open override func reset(): Tag {
        super.reset()
        attributes = None
        return this
    }
    public open func nameAttr(name: String, attributes: ?Attributes): StartTag {
        this.tagName.set(name)
        this.attributes = attributes
        normalName = ParseSettings.normalName(name)
        return this
    }
    public open override func toString(): String {
        let closer = if (selfClosing) {
            "/>"
        } else {
            ">"
        }
        return if (hasAttributes() && (attributes.size() > 0)) {
            "<${toStringName()} ${attributes}${closer}"
        } else {
            "<${toStringName()}${closer}"
        }
    }
}

class EndTag <: Tag & ToString {
    init(treeBuilder: TreeBuilder) {
        super(TokenType.EndTag, treeBuilder)
    }
    public open override func toString(): String {
        return "</${toStringName()}>"
    }
}

class Comment <: Token & ToString {
    init() {
        super(TokenType.Comment)
    }
    let data = TokenData()
    var bogus: Bool = false
    public open override func reset(): Token {
        super.reset()
        data.reset()
        bogus = false
        return this
    }
    public open func getData(): String {
        return data.value()
    }
    public open func append(append: String): Comment {
        data.append(append)
        return this
    }
    public open func append(append: Rune): Comment {
        data.append(append)
        return this
    }
    public open override func toString(): String {
        return "<!--${getData()}-->"
    }
}

open class Character <: Token & ToString {
    init() {
        super(TokenType.Character)
    }
    let _data: TokenData = TokenData()
    init(source: Character) {
        this()
        this.startPos = source.startPos
        this.endPos = source.endPos
        this.data.set(source.data.value())
    }
    public open override func reset(): Token {
        super.reset()
        _data.reset()
        return this
    }
    public open func data(str: String): Character {
        this.data.set(str)
        return this
    }
    public open func append(str: String): Character {
        _data.append(str)
        return this
    }
    public open func getData(): String {
        return _data.value()
    }
    public open override func toString(): String {
        return getData()
    }
    public open func normalizeNulls(replace: Bool) {
        var data = this.data.value()
        if (data.indexOf(TokeniserState.nullChar) == -1) {
            return
        }
        data = if (replace) {
            data.replace(TokeniserState.nullChar, Tokeniser.ReplacementChar)
        } else {
            data.replace(Character.nullString(), "")
        }
        this.data.set(data)
    }
    static func nullString(): String {
        return TokeniserState.nullChar.toString()
    }
}

class CData <: Character & ToString {
    init(data: String) {
        this.data(data)
    }
    public open override func toString(): String {
        return "<![CDATA[${data}]]>"
    }
}

class XmlDecl <: Tag & ToString {
    init(treeBuilder: TreeBuilder) {
        super(TokenType.XmlDecl, treeBuilder)
    }
    var isDeclaration: Bool = true
    public open override func reset(): XmlDecl {
        super.reset()
        isDeclaration = true
        return this
    }
    public open override func toString(): String {
        let `open` = if (isDeclaration) {
            "<!"
        } else {
            "<?"
        }
        let close = if (isDeclaration) {
            ">"
        } else {
            "?>"
        }
        return if (hasAttributes() && (attributes.size > 0)) {
            "${`open`}${toStringName()} ${attributes}${close}"
        } else {
            "${`open`}${toStringName()}${close}"
        }
    }
}

class EOF <: Token & ToString {
    init() {
        super(TokenType.EOF)
    }
    public open override func reset(): Token {
        super.reset()
        return this
    }
    public open override func toString(): String {
        return ""
    }
}

@Derive[Hashable, Equatable]
enum TokenType <: ToString {
    | Doctype | StartTag | EndTag | Comment | Character | XmlDecl | EOF
    public func toString(): String {
    return match (this) {
                case Doctype => "Doctype"
            case StartTag => "StartTag"
            case EndTag => "EndTag"
            case Comment => "Comment"
            case Character => "Character"
            case XmlDecl => "XmlDecl"
            case EOF => "EOF"
}
    }
}
