package ksoup_cj

import std.collection.*

class StringUtil {
    private init() {
        this._padding = ["", " ", "  ", "   ", "    ", "     ", "      ", "       ", "        ", "         ", "          ", "           ", "            ", "             ", "              ", "               ", "                ", "                 ", "                  ", "                   ", "                    "]
        this.controlChars = Regex("[\\x00-\\x1f]*")
        this.InitBuilderSize = 1024
        this.MaxBuilderSize = 8 * 1024
        this.BuilderPool = SoftPool({ => StringBuilder(InitBuilderSize) })
    }
    public static let INSTANCE = StringUtil()
    let _padding: Array<String>
    static func join(strings: ArrayList<Object>, sep: String): String {
        return join(strings.iterator(), sep)
    }
    static func join(strings: Iterator<Object>, sep: String): String {
        if (!strings.hasNext()) {
            return ""
        }
        let start = strings.next().toString()
        if (!strings.hasNext()) {
            return start
        }
        let j = StringJoiner(sep)
        j.add(start)
        while (strings.hasNext()) {
            j.add(strings.next())
        }
        return j.complete()
    }
    static func padding(width: Int64, maxPaddingWidth!: Int64 = 30): String {
        require(width >= 0, { => "width must be >= 0" })
        require(maxPaddingWidth >= -1)
        let effectiveWidth = if (maxPaddingWidth != -1) {
            (if (width < maxPaddingWidth) { width } else { maxPaddingWidth })
        } else {
            width
        }
        return if (effectiveWidth < StringUtil.INSTANCE._padding.size) {
            StringUtil.INSTANCE._padding[effectiveWidth]
        } else {
            (" " * effectiveWidth)
        }
    }
    static func isBlank(string: ?String): Bool {
        if (string.getOrThrow().isNullOrEmpty()) {
            return true
        }
        let l = string.getOrThrow().toRuneArray().size
        for (i in 0..l) {
            if (!isWhitespace(string.getOrThrow().codePointValueAt(i))) {
                return false
            }
        }
        return true
    }
    static func startsWithNewline(string: ?String): Bool {
        return if (string.getOrThrow().isNullOrEmpty()) {
            false
        } else {
            string[0] == r'\n'
        }
    }
    static func isNumeric(string: ?String): Bool {
        if (string.getOrThrow().isNullOrEmpty()) {
            return false
        }
        let l = string.getOrThrow().toRuneArray().size
        for (i in 0..l) {
            if (!isDigit(string[i])) {
                return false
            }
        }
        return true
    }
    static func isWhitespace(c: Int64): Bool {
        return ((((c == Int64(UInt32(r' '))) || (c == Int64(UInt32(r'\t')))) || (c == Int64(UInt32(r'\n')))) || (c == Int64(UInt32(r'\u{000c}')))) || (c == Int64(UInt32(r'\r')))
    }
    static func isActuallyWhitespace(c: Int64): Bool {
        return (((((c == Int64(UInt32(r' '))) || (c == Int64(UInt32(r'\t')))) || (c == Int64(UInt32(r'\n')))) || (c == Int64(UInt32(r'\u{000c}')))) || (c == Int64(UInt32(r'\r')))) || (c == 160)
    }
    static func isInvisibleChar(c: Int64): Bool {
        return (c == 8203) || (c == 173)
    }
    static func normaliseWhitespace(string: String): String {
        let sb: StringBuilder = borrowBuilder()
        appendNormalisedWhitespace(sb, string, false)
        return releaseBuilder(sb)
    }
    static func appendNormalisedWhitespace(accum: StringBuilder, string: String, stripLeading: Bool) {
        var lastWasWhite = false
        var reachedNonWhite = false
        let len = string.toRuneArray().size
        var c: CodePoint
        var i = 0
        while (i < len) {
            c = string.codePointAt(i)
            if (isActuallyWhitespace(c.value)) {
                if ((stripLeading && !reachedNonWhite) || lastWasWhite) {
                    i += c.charCount
                    continue
                }
                accum.append(r' ')
                lastWasWhite = true
            } else if (!isInvisibleChar(c.value)) {
                accum.appendCodePoint(c.value)
                lastWasWhite = false
                reachedNonWhite = true
            }
            i += c.charCount
        }
    }
    static func isIn(needle: String, haystack: Array<String>): Bool {
        let len = haystack.size
        for (i in 0..len) {
            if (haystack[i] == needle) {
                return true
            }
        }
        return false
    }
    static func inSorted(needle: String, haystack: Array<String>): Bool {
        return haystack.binarySearch(needle) >= 0
    }
    static func isAscii(string: String): Bool {
        for (element in string.runes()) {
            let c = Int64(UInt32(element))
            if (c > 127) {
                return false
            }
        }
        return true
    }
    static func resolve(baseUrl: String, relUrl: String): String {
        let cleanedBaseUrl = stripControlChars(baseUrl)
        let cleanedRelUrl = stripControlChars(relUrl)
        return URLUtil.resolve(cleanedBaseUrl, cleanedRelUrl)
    }
    let controlChars: Regex
    static func stripControlChars(input: String): String {
        return input.replace(StringUtil.INSTANCE.controlChars, "")
    }
    let InitBuilderSize: Int64
    let MaxBuilderSize: Int64
    let BuilderPool: SoftPool<StringBuilder>
    static func borrowBuilder(): StringBuilder {
        return StringUtil.INSTANCE.BuilderPool.borrow()
    }
    static func releaseBuilder(sb: StringBuilder): String {
        let str = sb.toString()
        releaseBuilderVoid(sb)
        return str
    }
    static func releaseBuilderVoid(sb: StringBuilder) {
        if (sb.toRuneArray().size <= StringUtil.INSTANCE.MaxBuilderSize) {
            sb.deleteRange(0, sb.toRuneArray().size)
            StringUtil.INSTANCE.BuilderPool.release(sb)
        }
    }
    static func isAsciiLetter(c: Rune): Bool {
        return ((c >= r'a') && (c <= r'z')) || ((c >= r'A') && (c <= r'Z'))
    }
    static func isDigit(c: Rune): Bool {
        return (c >= r'0') && (c <= r'9')
    }
    static func isHexDigit(c: Rune): Bool {
        return (isDigit(c) || ((c >= r'a') && (c <= r'f'))) || ((c >= r'A') && (c <= r'F'))
    }
}

class StringJoiner {
    let separator: String
    init(separator: String) {
        this.separator = separator
    }
    var sb: ?StringBuilder = borrowBuilder()
    var first = true
    func add(stringy: ?Object): StringJoiner {
        if (!first) {
            sb.getOrThrow().append(separator)
        }
        sb.getOrThrow().append(stringy)
        first = false
        return this
    }
    func append(stringy: ?Object): StringJoiner {
        sb.getOrThrow().append(stringy)
        return this
    }
    func complete(): String {
        let string = if (let Some(it) <- sb) {
            releaseBuilder(it)
        }
        sb = None
        return string ?? ""
    }
}
