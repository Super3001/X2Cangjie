package target_1g

import std.convert.*

class TokenQueue <: AutoCloseable & ToString {
    init(data: String) {
        this.reader = CharacterReader(data)
    }
    let reader: CharacterReader
    func isEmpty(): Bool {
        return reader.isEmpty()
    }
    func consume(): Rune {
        return reader.consume()
    }
    func advance() {
        if (!isEmpty()) {
            reader.advance()
        }
    }
    func current(): Rune {
        return reader.current()
    }
    func matches(seq: String): Bool {
        return reader.matchesIgnoreCase(seq)
    }
    func matches(c: Rune): Bool {
        return reader.matches(c)
    }
    func matchesAny(seq: Array<Rune>): Bool {
        return reader.matchesAny(seq)
    }
    func matchChomp(seq: String): Bool {
        return reader.matchConsumeIgnoreCase(seq)
    }
    func matchChomp(c: Rune): Bool {
        if (reader.matches(c)) {
            consume()
            return true
        }
        return false
    }
    func matchesWhitespace(): Bool {
        return reader.current().isAsciiWhiteSpace()
    }
    func matchesWord(): Bool {
        return reader.current().isLetterOrDigit()
    }
    func consume(seq: String) {
        if (!reader.matchConsumeIgnoreCase(seq)) {
            throw IllegalStateException("Queue did not match expected sequence")
        }
    }
    func consumeTo(seq: String): String {
        return reader.consumeTo(seq)
    }
    func consumeToAny(seq: Array<String>): String {
        let sb = StringUtil.borrowBuilder()
        loop
        { =>
            for (s in seq) {
                if (reader.matchesIgnoreCase(s)) {
                    break
                }
            }
            sb.append(consume())
        }
        return StringUtil.releaseBuilder(sb)
    }
    func chompBalanced(`open`: Rune, close: Rune): String {
        let accum = StringUtil.borrowBuilder()
        var depth = 0
        var prev: Rune = Rune(UInt32(0))
        var inSingle = false
        var inDouble = false
        var inRegexQE = false
        reader.mark()
        do {
            if (isEmpty()) {
                break
            }
            let c = consume()
            if (prev == TokenQueue.ESC) {
                if (c == r'Q') {
                    inRegexQE = true
                } else if (c == r'E') {
                    inRegexQE = false
                }
                accum.append(c)
            } else {
                if (((c == r'\'') && (c != `open`)) && !inDouble) {
                    inSingle = !inSingle
                } else if (((c == r'"') && (c != `open`)) && !inSingle) {
                    inDouble = !inDouble
                }
                if ((inSingle || inDouble) || inRegexQE) {
                    accum.append(c)
                } else if (c == `open`) {
                    depth += 1
                    if (depth > 1) {
                        accum.append(c)
                    }
                } else if (c == close) {
                    depth -= 1
                    if (depth > 0) {
                        accum.append(c)
                    }
                } else {
                    accum.append(c)
                }
            }
            prev = c
        } while (depth > 0)
        let out = StringUtil.releaseBuilder(accum)
        if (depth > 0) {
            reader.rewindToMark()
            Validate.fail("Did not find balanced marker at '${out}'")
        }
        return out
    }
    func consumeWhitespace(): Bool {
        var seen = false
        while (matchesWhitespace()) {
            advance()
            seen = true
        }
        return seen
    }
    func consumeElementSelector(): String {
        return consumeEscapedCssIdentifier(TokenQueue.ELEMENT_SELECTOR_CHARS())
    }
    func consumeCssIdentifier(): String {
        if (isEmpty()) {
            throw IllegalArgumentException("CSS identifier expected, but end of input found")
        }
        let identifier = reader.consumeMatching(isIdent)
        var c = current()
        if ((c != TokenQueue.ESC) && (c != TokenQueue.UNICODE_NULL)) {
            return identifier
        }
        let out = { =>
            let _also_it = StringUtil.borrowBuilder()
            let it = _also_it
            if (!(identifier.isEmpty())) {
                append(identifier)
            }
            return _also_it
        }()
        while (!isEmpty()) {
            c = current()
            if (isIdent(c)) {
                out.append(consume())
            } else if (c == TokenQueue.UNICODE_NULL) {
                advance()
                out.append(TokenQueue.REPLACEMENT)
            } else if (c == TokenQueue.ESC) {
                advance()
                if (!isEmpty() && isNewline(current())) {
                    reader.unconsume()
                    break
                } else {
                    consumeCssEscapeSequenceInto(out)
                }
            } else {
                break
            }
        }
        return StringUtil.releaseBuilder(out)
    }
    func consumeCssEscapeSequenceInto(out: StringBuilder) {
        if (isEmpty()) {
            out.append(TokenQueue.REPLACEMENT)
            return
        }
        let firstEsc = consume()
        if (!StringUtil.isHexDigit(firstEsc)) {
            out.append(firstEsc)
        } else {
            reader.unconsume()
            let hex = reader.consumeMatching({ it => StringUtil.isHexDigit(it) }, 6)
            let cp = hex.toIntOrNull(16) ?? throw
            IllegalArgumentException("Invalid escape sequence: ${hex}")
            if (isValidCodePoint(cp)) {
                out.appendCodePoint(cp)
            } else {
                out.append(TokenQueue.REPLACEMENT)
            }
            if (!isEmpty()) {
                let c2 = current()
                if (c2 == r'\r') {
                    advance()
                    if (!isEmpty() && (current() == r'\n')) {
                        advance()
                    }
                } else if (((c2 == r' ') || (c2 == r'\t')) || isNewline(c2)) {
                    advance()
                }
            }
        }
    }
    func consumeEscapedCssIdentifier(matches: Array<Rune>): String {
        let sb = StringUtil.borrowBuilder()
        while (!isEmpty()) {
            let c = current()
            if (c == TokenQueue.ESC) {
                advance()
                if (!isEmpty()) {
                    sb.append(consume())
                } else {
                    break
                }
            } else if (matchesCssIdentifier(matches)) {
                sb.append(c)
                advance()
            } else {
                break
            }
        }
        return StringUtil.releaseBuilder(sb)
    }
    func matchesCssIdentifier(matches: Array<Rune>): Bool {
        return matchesWord() || reader.matchesAny(matches)
    }
    func remainder(): String {
        return reader.consumeToEnd()
    }
    public override func toString(): String {
        return reader.toString()
    }
    public override func close() {
        reader.close()
    }
    static let ESC: Rune = r'\\'
    static let HYPHEN_MINUS: Rune = r'-'
    static let UNICODE_NULL: Rune = r'\u{0000}'
    static let REPLACEMENT: Rune = r'\u{FFFD}'
    static func ELEMENT_SELECTOR_CHARS(): Array<Rune> {
        return [r'*', r'|', r'_', r'-']
    }
    static func unescape(input: String): String {
        if (!input.contains(TokenQueue.ESC)) {
            return input
        }
        let out = StringUtil.borrowBuilder()
        var last: Rune = Rune(UInt32(0))
        for (c in input.runes()) {
            if (c == TokenQueue.ESC) {
                if (last == TokenQueue.ESC) {
                    out.append(c)
                    last = Rune(UInt32(0))
                    continue
                }
            } else {
                out.append(c)
            }
            last = c
        }
        return StringUtil.releaseBuilder(out)
    }
    static func escapeCssIdentifier(input: String): String {
        if (input.isEmpty()) {
            return input
        }
        let out = StringUtil.borrowBuilder()
        let q = TokenQueue(input)
        let firstChar = q.current()
        if (firstChar == TokenQueue.HYPHEN_MINUS) {
            q.advance()
            if (q.isEmpty()) {
                appendEscaped(out, TokenQueue.HYPHEN_MINUS)
            } else {
                out.append(TokenQueue.HYPHEN_MINUS)
                if (StringUtil.isAsciiNumber(q.current())) {
                    appendEscapedCodepoint(out, q.consume())
                }
            }
        } else if (StringUtil.isAsciiNumber(firstChar)) {
            appendEscapedCodepoint(out, q.consume())
        }
        while (!q.isEmpty()) {
            let c = q.consume()
            if (c == TokenQueue.UNICODE_NULL) {
                out.append(TokenQueue.REPLACEMENT)
            } else if ((c <= r'\u{001F}') || (c == r'\u{007F}')) {
                appendEscapedCodepoint(out, c)
            } else if (isIdent(c)) {
                out.append(c)
            } else {
                appendEscaped(out, c)
            }
        }
        q.close()
        return StringUtil.releaseBuilder(out)
    }
    static func appendEscaped(out: StringBuilder, c: Rune) {
        out.append(TokenQueue.ESC).append(c)
    }
    static func appendEscapedCodepoint(out: StringBuilder, c: Rune) {
        out.append(TokenQueue.ESC).append(Int64(UInt32(c)).toString(radix: 16)).append(r' ')
    }
    static func isNonAscii(c: Rune): Bool {
        return c >= r'\u{0080}'
    }
    static func isIdentStart(c: Rune): Bool {
        return ((c == r'_') || StringUtil.isAsciiLetter(c)) || isNonAscii(c)
    }
    static func isIdent(c: Rune): Bool {
        return ((c == TokenQueue.HYPHEN_MINUS) || StringUtil.isAsciiNumber(c)) || isIdentStart(c)
    }
    static func isNewline(c: Rune): Bool {
        return ((c == r'\n') || (c == r'\r')) || (c == r'\u{000C}')
    }
    static func isValidCodePoint(codePoint: Int64): Bool {
        return ((codePoint != 0) && Character.isValidCodePoint(codePoint)) && !Rune(UInt32(codePoint)).isSurrogate()
    }
}
