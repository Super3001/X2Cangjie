package target_1g

class ParseSettings {
    let preserveTagCase: Bool
    let preserveAttributeCase: Bool
    init(preserveTagCase: Bool, preserveAttributeCase: Bool) {
        this.preserveTagCase = preserveTagCase
        this.preserveAttributeCase = preserveAttributeCase
    }
    init(copy: ?ParseSettings) {
        this(copy.getOrThrow().preserveTagCase)
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
