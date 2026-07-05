package target_1g

class Normalizer {
    private init() {}
    public static let INSTANCE = Normalizer()
    static func lowerCase(input: ?String): String {
        return input?.toAsciiLower() ?? ""
    }
    static func normalize(input: ?String): String {
        return lowerCase(input).trimAscii({ it => it <= r' ' })
    }
    static func normalize(input: ?String, isStringLiteral: Bool): String {
        return if (isStringLiteral) {
            lowerCase(input)
        } else {
            normalize(input)
        }
    }
    static func xmlSafeTagName(tagname: String): ?String {
        return Attribute.getValidKey(tagname, Document.OutputSettings.Syntax.xml)
    }
}
