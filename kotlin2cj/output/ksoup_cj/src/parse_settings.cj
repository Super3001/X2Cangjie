package ksoup_cj

class ParseSettings {
    let _preserveTagCase: Bool
    let _preserveAttributeCase: Bool
    init(preserveTagCase: Bool, preserveAttributeCase: Bool) {
        this._preserveTagCase = preserveTagCase
        this._preserveAttributeCase = preserveAttributeCase
    }
    func preserveTagCase(): Bool {
        return _preserveTagCase
    }
    func preserveAttributeCase(): Bool {
        return _preserveAttributeCase
    }
    init(copy: ?ParseSettings) {
        this(copy.getOrThrow().preserveTagCase, copy.getOrThrow().preserveAttributeCase)
    }
    func normalizeTag(name: String): String {
        var trimmedName = name.trimAscii({ it => it <= r' ' })
        if (!preserveTagCase) {
            trimmedName = lowerCase(trimmedName)
        }
        return trimmedName
    }
    func normalizeAttribute(name: String): String {
        var trimmedName = name.trimAscii({ it => it <= r' ' })
        if (!preserveAttributeCase) {
            trimmedName = lowerCase(trimmedName)
        }
        return trimmedName
    }
    func normalizeAttributes(attributes: ?Attributes) {
        if (!preserveAttributeCase) {
            attributes?.normalize()
        }
    }
    static func htmlDefault(): ParseSettings {
        return ParseSettings(false, false)
    }
    static func preserveCase(): ParseSettings {
        return ParseSettings(true, true)
    }
    static func normalName(name: ?String): String {
        return normalize(name.getOrThrow().trimAscii({ it => it <= r' ' }))
    }
}
