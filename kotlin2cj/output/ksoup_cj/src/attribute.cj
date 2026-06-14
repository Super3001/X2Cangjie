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

open class Attribute <: Map.Entry & KCloneable & ToString {
    init(key: String, value: ?String, parent: ?Attributes) {
        var sKey = key
        sKey = sKey.trimAscii({ it => it <= r' ' })
        Validate.notEmpty(sKey)
        this._attributeKey = sKey
        this.attributeValue = value
        this.parent = parent
    }
    var _attributeKey: String
    var attributeValue: ?String
    var parent: ?Attributes
    init(key: String, value: ?String) {
        this(key, value, None)
    }
    let key: String
    public open func setKey(key: String) {
        let trimmedKey = key.trimAscii({ it => it <= r' ' })
        Validate.notEmpty(trimmedKey)
        if (let Some(parentValue) <- parent) {
            let parent = parentValue
            let i = parent.getOrThrow().indexOfKey(this.key)
            if (i != Attributes.NotFound) {
                let oldKey = parent.getOrThrow().keys()[i]
                parent.getOrThrow().keys()[i] = trimmedKey
                let ranges: ?HashMap<String, AttributeRange> = parent.getOrThrow().getRanges()
                if (let Some(rangesValue) <- ranges) {
                    let ranges = rangesValue
                    let range: ?AttributeRange = ranges.remove(oldKey)
                    if (let Some(rangeValue) <- range) {
                        let range = rangeValue
                        ranges[trimmedKey] = range
                    }
                }
            }
        }
        this._attributeKey = trimmedKey
    }
    let value: String
    public open func hasDeclaredValue(): Bool {
        return attributeValue.isSome()
    }
    public open func setValue(newValue: ?String): String {
        var oldVal = this.attributeValue
        if (let Some(parentValue) <- parent) {
            let parent = parentValue
            let i: Int64 = parent.getOrThrow().indexOfKey(attributeKey)
            if (i != Attributes.NotFound) {
                oldVal = parent.getOrThrow()[attributeKey]
                parent.getOrThrow().vals[i] = newValue
            }
        }
        this.attributeValue = newValue
        return Attributes.checkNotNull(oldVal)
    }
    public open func prefix(): String {
        let pos = (key.indexOf(":") ?? -1)
        return if (pos == -1) {
            ""
        } else {
            __k2cjRuneSlice(key, 0, pos)
        }
    }
    public open func localName(): String {
        let pos = (key.indexOf(":") ?? -1)
        return if (pos == -1) {
            key
        } else {
            __k2cjRuneSlice(key, pos + 1, key.toRuneArray().size)
        }
    }
    public open func namespace(): String {
        return if (let Some(parentValue) <- parent) {
            let parent = parentValue
            let ns = (if (parent?.userData(SharedConstants.XmlnsAttr + prefix()) is String) { parent?.userData(SharedConstants.XmlnsAttr + prefix()) as String } else { None })
            ns ?? ""
        } else {
            ""
        }
    }
    public open func html(): String {
        let sb: StringBuilder = borrowBuilder()
        html(QuietAppendable.wrap(sb), OutputSettings())
        return releaseBuilder(sb)
    }
    public open func html(accum: Appendable, out: OutputSettings): Unit {
        html(key, value, accum, out)
    }
    public open func html(key: String, value: String, accum: Appendable, out: OutputSettings): Unit {
        html(key, value, QuietAppendable.wrap(accum), out)
    }
    public open func sourceRange(): AttributeRange {
        if (parent.isNone()) {
            return AttributeRange.UntrackedAttr
        }
        return parent.getOrThrow().sourceRange(key)
    }
    public open func html(accum: QuietAppendable, out: OutputSettings): Unit {
        html(attributeKey, attributeValue, accum, out)
    }
    public open override func toString(): String {
        return html()
    }
    public open override func equals(other: ?Object): Bool {
        if (this == other) {
            return true
        }
        if ((other.isNone()) || (this != other)) {
            return false
        }
        let attribute: Attribute = (other as Attribute)
        if (attributeKey != attribute.attributeKey) {
            return false
        }
        return (attributeKey == attribute.key) && (attributeValue == attribute.attributeValue)
    }
    public open override func hashCode(): Int64 {
        return [attributeKey, attributeValue].contentHashCode()
    }
    public open override func clone(): Attribute {
        let attribute = Attribute(attributeKey, attributeValue)
        attribute.parent = this.parent
        return attribute
    }
    public open func isDataAttribute(): Bool {
        return isDataAttribute(key)
    }
    public open func isInternal(): Bool {
        return Attributes.isInternalKey(key)
    }
    static func booleanAttributes(): __ArrayLiteral<String> {
        return ["allowfullscreen", "async", "autofocus", "checked", "compact", "declare", "default", "defer", "disabled", "formnovalidate", "hidden", "inert", "ismap", "itemscope", "multiple", "muted", "nohref", "noresize", "noshade", "novalidate", "nowrap", "open", "readonly", "required", "reversed", "seamless", "selected", "sortable", "truespeed", "typemustmatch"]
    }
    public static func html(key: String, value: ?String, accum: QuietAppendable, out: OutputSettings) {
        let resultKey: String = getValidKey(key, out.syntax()) ?? return
        htmlNoValidate(resultKey, value, accum, out)
    }
    public static func htmlNoValidate(key: String, value: ?String, accum: QuietAppendable, out: OutputSettings) {
        accum.append(key)
        if (!shouldCollapseAttribute(key, value, out)) {
            accum.append("=\"")
            Entities.escape(accum, Attributes.checkNotNull(value), out, Entities.ForAttribute)
            accum.append(r'"')
        }
    }
    static func xmlKeyReplace(): Regex {
        return Regex("[^-a-zA-Z0-9_:.]+")
    }
    static func htmlKeyReplace(): Regex {
        return Regex("[\\x00-\\x1f\\x7f-\\x9f \"'/=]+")
    }
    public static func getValidKey(key: String, syntax: Syntax): ?String {
        return match (syntax) {
            case Syntax.xml => 
                if (!isValidXmlKey(key)) {
                    let newKey = Attribute.xmlKeyReplace().replace(key, "_")
                    if (isValidXmlKey(newKey)) {
                        newKey
                    } else {
                        None
                    }
                } else {
                    key
                }
            case Syntax.html => 
                if (!isValidHtmlKey(key)) {
                    let newKey = Attribute.htmlKeyReplace().replace(key, "_")
                    if (isValidHtmlKey(newKey)) {
                        newKey
                    } else {
                        None
                    }
                } else {
                    key
                }
            case _ => ()}
    }
    public static func isValidXmlKey(key: String): Bool {
        let length = key.toRuneArray().size
        if (length == 0) {
            return false
        }
        var c = key.toRuneArray()[0]
        if (!((((c >= r'a' && c <= r'z') || (c >= r'A' && c <= r'Z')) || (c == r'_')) || (c == r':'))) {
            return false
        }
        for (i in 1..length) {
            c = key.toRuneArray()[i]
            if (!(((((((c >= r'a' && c <= r'z') || (c >= r'A' && c <= r'Z')) || (c >= r'0' && c <= r'9')) || (c == r'-')) || (c == r'_')) || (c == r':')) || (c == r'.'))) {
                return false
            }
        }
        return true
    }
    public static func isValidHtmlKey(key: String): Bool {
        let length = key.toRuneArray().size
        if (length == 0) {
            return false
        }
        for (i in 0..length) {
            let c = key.toRuneArray()[i]
            if (((((((Int64(UInt32(c)) <= 0x1f) || (Int64(UInt32(c)) >= 0x7f && Int64(UInt32(c)) <= 0x9f)) || (c == r' ')) || (c == r'"')) || (c == r'\'')) || (c == r'/')) || (c == r'=')) {
                return false
            }
        }
        return true
    }
    public static func createFromEncoded(unencodedKey: String, encodedValue: String): Attribute {
        let value: String = Entities.unescape(encodedValue, true)
        return Attribute(unencodedKey, value, None)
    }
    public static func isDataAttribute(key: String): Bool {
        return key.startsWith(Attributes.dataPrefix) && (key.toRuneArray().size > Attributes.dataPrefix.toRuneArray().size)
    }
    public static func shouldCollapseAttribute(key: String, value: ?String, out: OutputSettings): Bool {
        return (out.syntax() == Syntax.html) && ((value.isNone()) || ((value.getOrThrow().isEmpty() || value.getOrThrow().equals(key, true)) && isBooleanAttribute(key)))
    }
    public static func isBooleanAttribute(key: String): Bool {
        return Attribute.booleanAttributes().binarySearchBy({ it => it.compareTo(key.toAsciiLower()) }) >= 0
    }
}
