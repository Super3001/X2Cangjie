package target_1g

import std.collection.*
import std.deriving.*
import std.convert.*

class Entities {
    private init() {
        this.ForText = 0x1
        this.ForAttribute = 0x2
        this.Normalise = 0x4
        this.TrimLeading = 0x8
        this.TrimTrailing = 0x10
        this.empty = -1
        this.emptyName = ""
        this.codepointRadix = 36
        this.codeDelims = [r',', r';']
        this.multipoints = HashMap<String, String>()
        this.BaseCount = 106
        this.baseSorted = ArrayList<String>([BaseCount])
        this.LocalEncoder = ThreadLocal<?CharsetEncoder>({ => None })
        this.charBuf = ThreadLocal({ => Array<Rune>(2, { _ => r'\u{0000}' }) })
    }
    public static let INSTANCE = Entities()
    let ForText: Int64
    let ForAttribute: Int64
    let Normalise: Int64
    let TrimLeading: Int64
    let TrimTrailing: Int64
    let empty: Int64
    let emptyName: String
    let codepointRadix: Int64
    let codeDelims: Array<Rune>
    let multipoints: HashMap<String, String>
    let BaseCount: Int64
    let baseSorted: ArrayList<String>
    let LocalEncoder: ThreadLocal<?CharsetEncoder>
    static func encoderFor(charset: Charset): CharsetEncoder {
        var encoder = Entities.INSTANCE.LocalEncoder.get()
        if ((encoder.isNone()) || (encoder.charset() != charset)) {
            encoder = charset.newEncoder()
            Entities.INSTANCE.LocalEncoder.setValue(encoder)
        }
        return encoder
    }
    static func isNamedEntity(name: String): Bool {
        return extended.codepointForName(name) != Entities.INSTANCE.empty
    }
    static func isBaseNamedEntity(name: String): Bool {
        return base.codepointForName(name) != Entities.INSTANCE.empty
    }
    static func getByName(name: String): String {
        let value: ?String = Entities.INSTANCE.multipoints[name]
        if (let Some(valueValue) <- value) {
            let value = valueValue
            return value
        }
        let codepoint = extended.codepointForName(name)
        return if (codepoint != Entities.INSTANCE.empty) {
            Rune(UInt32(codepoint)).toString()
        } else {
            Entities.INSTANCE.emptyName
        }
    }
    static func codepointsForName(name: String, codepoints: IntArray): Int64 {
        let value: ?String = Entities.INSTANCE.multipoints[name]
        if (let Some(valueValue) <- value) {
            let value = valueValue
            codepoints[0] = value.codePointValueAt(0)
            codepoints[1] = value.codePointValueAt(1)
            return 2
        }
        let codepoint = extended.codepointForName(name)
        if (codepoint != Entities.INSTANCE.empty) {
            codepoints[0] = codepoint
            return 1
        }
        return 0
    }
    static func findPrefix(input: String): String {
        for (name in Entities.INSTANCE.baseSorted) {
            if (input.startsWith(name)) {
                return name
            }
        }
        return Entities.INSTANCE.emptyName
    }
    static func escape(data: ?String, out: OutputSettings): String {
        return escapeString(data, out.escapeMode(), out.charset())
    }
    static func escape(data: ?String): String {
        return escapeString(data, base, Charsets.UTF8)
    }
    static func escapeString(data: ?String, escapeMode: EscapeMode, charset: Charset): String {
        if (data.isNone()) {
            return ""
        }
        let sb = borrowBuilder()
        doEscape(data, QuietAppendable.wrap(sb), escapeMode, charset, Entities.INSTANCE.ForText | Entities.INSTANCE.ForAttribute)
        return releaseBuilder(sb)
    }
    static func escape(accum: QuietAppendable, data: String, out: OutputSettings, options: Int64) {
        doEscape(data, accum, out.escapeMode(), out.charset(), options)
    }
    static func doEscape(data: String, accum: QuietAppendable, mode: EscapeMode, charset: Charset, options: Int64) {
        let coreCharset: CoreCharset = CoreCharset.byName(charset.name())
        let fallback: CharsetEncoder = encoderFor(charset)
        let length = data.toRuneArray().size
        var codePoint: CodePoint
        var lastWasWhite = false
        var reachedNonWhite = false
        var skipped = false
        var offset = 0
        while (offset < length) {
            codePoint = data.codePointAt(offset)
            if ((options & Entities.INSTANCE.Normalise) != 0) {
                if (StringUtil.isAsciiWhiteSpace(codePoint.value)) {
                    if (((options & Entities.INSTANCE.TrimLeading) != 0) && !reachedNonWhite) {
                        offset += codePoint.charCount
                        continue
                    }
                    if (lastWasWhite) {
                        offset += codePoint.charCount
                        continue
                    }
                    if ((options & Entities.INSTANCE.TrimTrailing) != 0) {
                        skipped = true
                        offset += codePoint.charCount
                        continue
                    }
                    accum.append(r' ')
                    lastWasWhite = true
                    offset += codePoint.charCount
                    continue
                } else {
                    lastWasWhite = false
                    reachedNonWhite = true
                    if (skipped) {
                        accum.append(r' ')
                        skipped = false
                    }
                }
            }
            appendEscaped(codePoint, accum, options, mode, coreCharset, fallback)
            offset += codePoint.charCount
        }
    }
    static func appendEscaped(codePoint: CodePoint, accum: QuietAppendable, options: Int64, escapeMode: EscapeMode, coreCharset: CoreCharset, fallback: CharsetEncoder) {
        if ((EscapeMode.xhtml == escapeMode) && !isValidXmlChar(codePoint.value)) {
            return
        }
        let c = Rune(UInt32(codePoint.value))
        if (codePoint.value < Character.MIN_SUPPLEMENTARY_CODE_POINT) {
            if (c == r'&') {
                accum.append("&amp;")
            } else if (c.code == 0xA0) {
                appendNbsp(accum, escapeMode)
            } else if (c == r'<') {
                accum.append("&lt;")
            } else if (c == r'>') {
                accum.append("&gt;")
            } else if (c == r'"') {
                if ((options & Entities.INSTANCE.ForAttribute) != 0) {
                    accum.append("&quot;")
                } else {
                    accum.append(c)
                }
            } else if (c == r'\'') {
                appendApos(accum, options, escapeMode)
            } else if (((c.code == 0x9) || (c.code == 0xA)) || (c.code == 0xD)) {
                accum.append(c)
            } else {
                if ((c.code < 0x20) || !canEncode(coreCharset, c, fallback)) {
                    appendEncoded(accum, escapeMode, codePoint.value)
                } else {
                    accum.append(c)
                }
            }
        } else {
            if (canEncode(coreCharset, c, fallback)) {
                let chars = Entities.INSTANCE.charBuf.get()
                let len = codePoint.toChars(chars, 0)
                accum.append(chars, 0, len)
            } else {
                appendEncoded(accum, escapeMode, codePoint.value)
            }
        }
    }
    let charBuf: ThreadLocal<Array<Rune>>
    static func appendNbsp(accum: QuietAppendable, escapeMode: EscapeMode) {
        if (escapeMode != EscapeMode.xhtml) {
            accum.append("&nbsp;")
        } else {
            accum.append("&#xa0;")
        }
    }
    static func appendApos(accum: QuietAppendable, options: Int64, escapeMode: EscapeMode) {
        if (((options & Entities.INSTANCE.ForAttribute) != 0) && ((options & Entities.INSTANCE.ForText) != 0)) {
            if (escapeMode == EscapeMode.xhtml) {
                accum.append("&#x27;")
            } else {
                accum.append("&apos;")
            }
        } else {
            accum.append(r'\'')
        }
    }
    static func appendEncoded(accum: QuietAppendable, escapeMode: EscapeMode, codePoint: Int64) {
        let name = escapeMode.nameForCodepoint(codePoint)
        if (Entities.INSTANCE.emptyName != name) {
            accum.append(r'&').append(name).append(r';')
        } else {
            accum.append("&#x").append(codePoint.toHexString(HexFormat({ => number({ => removeLeadingZeros = true }) }))).append(r';')
        }
    }
    static func unescape(string: String): String {
        return unescape(string, false)
    }
    static func unescape(string: String, strict: Bool): String {
        return Parser.unescapeEntities(string, strict)
    }
    static func canEncode(charset: CoreCharset, c: Rune, fallback: CharsetEncoder): Bool {
        return match (charset) {
            case CoreCharset.ascii => Int64(UInt32(c)) <= 0x80
            case CoreCharset.utf => !((c >= Character.MIN_SURROGATE) && (Int64(UInt32(c)) < (Character.MAX_SURROGATE.code + 1)))
            case _ => fallback.canEncode(c)}
    }
    static func isValidXmlChar(codePoint: Int64): Bool {
        return (((((codePoint == 0x9) || (codePoint == 0xA)) || (codePoint == 0xD)) || (codePoint >= 0x20 && codePoint <= 0xD7FF)) || (codePoint >= 0xE000 && codePoint <= 0xFFFD)) || (codePoint >= 0x10000 && codePoint <= 0x10FFFF)
    }
    static func load(e: EscapeMode, pointsData: String, size: Int64) {
        e.nameKeys = arrayOfNulls(size)
        e.codeVals = IntArray(size)
        e.codeKeys = IntArray(size)
        e.nameVals = arrayOfNulls(size)
        var i = 0
        CharacterReader(pointsData).use({ reader =>
            while (!reader.isEmpty()) {
                let name: String = reader.consumeTo(r'=')
                reader.advance()
                let cp1: Int64 = Int64.parse(reader.consumeToAny(Entities.INSTANCE.codeDelims), radix: Entities.INSTANCE.codepointRadix)
                let codeDelim: Rune = reader.current()
                reader.advance()
                let cp2: Int64
                if (codeDelim == r',') {
                    cp2 = Int64.parse(reader.consumeTo(r';'), radix: Entities.INSTANCE.codepointRadix)
                    reader.advance()
                } else {
                    cp2 = Entities.INSTANCE.empty
                }
                let indexS: String = reader.consumeTo(r'&')
                let index = Int64.parse(indexS, radix: Entities.INSTANCE.codepointRadix)
                reader.advance()
                e.nameKeys[i] = name
                e.codeVals[i] = cp1
                e.codeKeys[index] = cp1
                e.nameVals[index] = name
                if (cp2 != Entities.INSTANCE.empty) {
                    Entities.INSTANCE.multipoints[name] = [Rune(UInt32(cp1)), Rune(UInt32(cp2))].concatToString()
                }
                i += 1
            }
            Validate.isTrue(i == size, "Unexpected count of entities loaded")
        })
    }
    static func codepointForName(name: String): Int64 {
        let index: Int64 = nameKeys.binarySearch(name)
        return if (index >= 0) {
            codeVals[index]
        } else {
            Entities.INSTANCE.empty
        }
    }
    static func nameForCodepoint(codepoint: Int64): String {
        let index: Int64 = codeKeys.binarySearch(codepoint)
        return if (index >= 0) {
            if ((index < (nameVals.size - 1)) && (codeKeys[index + 1] == codepoint)) {
                nameVals[index + 1]
            } else {
                nameVals[index]
            }
        } else {
            Entities.INSTANCE.emptyName
        }
    }
}

class EscapeMode <: ToString & Equatable<EscapeMode> {
    let _ordinal: Int64
    public let file: String
    public let size: Int64
    init(_ordinal: Int64, file: String, size: Int64) {
        this._ordinal = _ordinal
        this.file = file
        this.size = size
    }
    public static let xhtml = EscapeMode(0, EntitiesData.xmlPoints, 4)
    public static let base = EscapeMode(1, EntitiesData.basePoints, 106)
    public static let extended = EscapeMode(2, EntitiesData.fullPoints, 2125)
    public func toString(): String {
            if (this == EscapeMode.xhtml) { return "xhtml" }
            if (this == EscapeMode.base) { return "base" }
            if (this == EscapeMode.extended) { return "extended" }
return "EscapeMode(?)"
    }
    public operator func ==(rhs: EscapeMode): Bool {
        return this._ordinal == rhs._ordinal
    }
    public operator func !=(rhs: EscapeMode): Bool {
        return !(this == rhs)
    }
}

@Derive[Hashable, Equatable]
enum CoreCharset <: ToString {
    | ascii | utf | fallback
    public func toString(): String {
    return match (this) {
                case ascii => "ascii"
            case utf => "utf"
            case fallback => "fallback"
}
    }
}
