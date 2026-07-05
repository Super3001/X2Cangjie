package target_1g

import std.convert.*

class Tokeniser {
    init(treeBuilder: TreeBuilder) {
        this.reader = treeBuilder.reader
        this.errors = treeBuilder.parser.getErrors()
        this.syntax = if ((treeBuilder is XmlTreeBuilder)) {
    Document.OutputSettings.Syntax.xml
} else {
    Document.OutputSettings.Syntax.html
}
        this.startPending = Token.StartTag(treeBuilder)
        this.endPending = Token.EndTag(treeBuilder)
        this.xmlDeclPending = Token.XmlDecl(treeBuilder)
    }
    let reader: CharacterReader
    let errors: ParseErrorList
    var state = TokeniserState.Data
    var emitPending: ?Token = None
    var isEmitPending = false
    let dataBuffer: TokenData = TokenData()
    let syntax: Document.OutputSettings.Syntax
    let startPending: StartTag
    let endPending: EndTag
    var tagPending: Token.Tag = startPending
    let charPending = Token.Character()
    let doctypePending: Token.Doctype = Token.Doctype()
    let commentPending: Token.Comment = Token.Comment()
    let xmlDeclPending: Token.XmlDecl
    var lastStartTag: ?String = None
    var lastStartCloseSeq: ?String = None
    var markupStartPos = 0
    var charStartPos = 0
    let codepointHolder = IntArray(1)
    let multipointHolder = IntArray(2)
    func read(): Token {
        while (!isEmitPending) {
            state.read(this, reader)
        }
        return if (charPending.data.hasData()) {
            charPending
        } else {
            isEmitPending = false
            checkNotNull(emitPending)
        }
    }
    func emit(token: Token) {
        Validate.isFalse(isEmitPending)
        emitPending = token
        isEmitPending = true
        token.startPos(markupStartPos)
        token.endPos(reader.pos())
        charStartPos = reader.pos()
        match (token.`type`) {
            case Token.TokenType.StartTag => 
                let startTag = (token as Token.StartTag)
                lastStartTag = startTag.name()
                lastStartCloseSeq = None
            case Token.TokenType.EndTag => 
                let endTag = (token as Token.EndTag)
                if (endTag.hasAttributes()) {
                    error("Attributes incorrectly present on end tag [/${endTag.retrieveNormalName()}]")
                }
            case _ => ()}
    }
    func emit(str: String) {
        charPending.append(str)
        charPending.startPos(charStartPos)
        charPending.endPos(reader.pos())
    }
    func emit(c: Rune) {
        charPending.data.append(c)
        charPending.startPos(charStartPos)
        charPending.endPos(reader.pos())
    }
    func emit(codepoints: IntArray): Unit {
        emit(codepoints.codePointsToString())
    }
    func transition(newState: TokeniserState) {
        if (newState == TokeniserState.TagOpen) {
            markupStartPos = reader.pos()
        }
        this.state = newState
    }
    func advanceTransition(newState: TokeniserState) {
        transition(newState)
        reader.advance()
    }
    func consumeCharacterReference(additionalAllowedCharacter: ?Rune, inAttribute: Bool): ?IntArray {
        if (reader.isEmpty()) {
            return None
        }
        if ((additionalAllowedCharacter.isSome()) && (additionalAllowedCharacter == reader.current())) {
            return None
        }
        if (reader.matchesAnySorted(Tokeniser.notCharRefCharsSorted())) {
            return None
        }
        let codeRef = codepointHolder
        reader.mark()
        if (reader.matchConsume("#")) {
            let isHexMode = reader.matchConsumeIgnoreCase("X")
            let numRef = if (isHexMode) {
                reader.consumeHexSequence()
            } else {
                reader.consumeDigitSequence()
            }
            if (numRef.isEmpty()) {
                characterReferenceError("numeric reference with no numerals")
                reader.rewindToMark()
                return None
            }
            reader.unmark()
            if (!reader.matchConsume(";")) {
                characterReferenceError("missing semicolon on [&#${numRef}]")
            }
            var charval = try {
                Int64.parse(numRef, radix: if (isHexMode) {
                    16
                } else {
                    10
                })
            } catch (e: IllegalArgumentException) {
                -1
            }
            if ((charval == -1) || (charval > 0x10FFFF)) {
                characterReferenceError("character [${charval}] outside of valid range")
                codeRef[0] = Tokeniser.ReplacementChar.code
            } else {
                if ((charval >= Tokeniser.win1252ExtensionsStart) && (charval < (Tokeniser.win1252ExtensionsStart + Tokeniser.win1252Extensions().size))) {
                    characterReferenceError("character [${charval}] is not a valid unicode code point")
                    charval = Tokeniser.win1252Extensions()[charval - Tokeniser.win1252ExtensionsStart]
                }
                codeRef[0] = charval
            }
            return codeRef
        } else {
            var nameRef = reader.consumeLetterThenDigitSequence()
            let looksLegit = reader.matches(r';')
            let found = Entities.isBaseNamedEntity(nameRef) || (Entities.isNamedEntity(nameRef) && looksLegit)
            if (!found) {
                reader.rewindToMark()
                if (looksLegit) {
                    characterReferenceError("invalid named reference [${nameRef}]")
                }
                if (inAttribute) {
                    return None
                }
                let prefix = Entities.findPrefix(nameRef)
                if (prefix.isEmpty()) {
                    return None
                }
                reader.matchConsume(prefix)
                nameRef = prefix
            }
            if (inAttribute && ((reader.matchesAsciiAlpha() || reader.matchesDigit()) || reader.matchesAny(r'=', r'-', r'_'))) {
                reader.rewindToMark()
                return None
            }
            reader.unmark()
            if (!reader.matchConsume(";")) {
                characterReferenceError("missing semicolon on [&${nameRef}]")
            }
            let numChars = Entities.codepointsForName(nameRef, multipointHolder)
            return match (numChars) {
                case 1 => 
                    codeRef[0] = multipointHolder[0]
                    codeRef
                case 2 => multipointHolder
                case _ => 
                    Validate.fail("Unexpected characters returned for ${nameRef}")
                    multipointHolder}
        }
    }
    func createTagPending(start: Bool): Token.Tag {
        tagPending = if (start) {
            startPending.reset()
        } else {
            endPending.reset()
        }
        return tagPending
    }
    func createXmlDeclPending(isDeclaration: Bool): Token.XmlDecl {
        let decl: Token.XmlDecl = xmlDeclPending.reset()
        decl.isDeclaration = isDeclaration
        tagPending = decl
        return decl
    }
    func emitTagPending() {
        tagPending.finaliseTag()
        emit(tagPending)
    }
    func createCommentPending() {
        commentPending.reset()
    }
    func emitCommentPending() {
        emit(commentPending)
    }
    func createBogusCommentPending() {
        commentPending.reset()
        commentPending.bogus = true
    }
    func createDoctypePending() {
        doctypePending.reset()
    }
    func emitDoctypePending() {
        emit(doctypePending)
    }
    func createTempBuffer() {
        dataBuffer.reset()
    }
    func isAppropriateEndTagToken(): Bool {
        return (lastStartTag.isSome()) && (tagPending.name().toAsciiLower() == lastStartTag.toAsciiLower())
    }
    func appropriateEndTagName(): ?String {
        return lastStartTag
    }
    func appropriateEndTagSeq(): String {
        if (lastStartCloseSeq.isNone()) {
            lastStartCloseSeq = "</${lastStartTag}"
        }
        return lastStartCloseSeq.getOrThrow()
    }
    func error(state: ?TokeniserState) {
        if (errors.canAddError()) {
            errors.add(ParseError(reader, "Unexpected character '${reader.current()}' in input state [${state}]"))
        }
    }
    func eofError(state: ?TokeniserState) {
        if (errors.canAddError()) {
            errors.add(ParseError(reader, "Unexpectedly reached end of file (EOF) in input state [${state}]"))
        }
    }
    func characterReferenceError(message: String) {
        if (errors.canAddError()) {
            errors.add(ParseError(reader, "Invalid character reference: ${message}"))
        }
    }
    func error(errorMsg: String) {
        if (errors.canAddError()) {
            errors.add(ParseError(reader, errorMsg))
        }
    }
    func unescapeEntities(inAttribute: Bool): String {
        let builder: StringBuilder = StringUtil.borrowBuilder()
        while (!reader.isEmpty()) {
            builder.append(reader.consumeTo(r'&'))
            if (reader.matches(r'&')) {
                reader.consume()
                let c = consumeCharacterReference(None, inAttribute)
                if ((c.isNone()) || c.isEmpty()) {
                    builder.append(r'&')
                } else {
                    builder.appendCodePoint(c[0])
                    if (c.size == 2) {
                        builder.appendCodePoint(c[1])
                    }
                }
            }
        }
        return StringUtil.releaseBuilder(builder)
    }
    static let ReplacementChar: Rune = r'\u{FFFD}'
    static func notCharRefCharsSorted(): Array<Rune> {
        return [r'\t', r'\n', r'\r', r'\u{000c}', r' ', r'<', r'&'].sortedArray()
    }
    static let win1252ExtensionsStart: Int64 = 0x80
    static func win1252Extensions(): IntArray {
        return intArrayOf(0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F, 0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178)
    }
}
