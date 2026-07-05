package target_1g

import std.convert.*

class CodePoint <: ToString {
    let value: Int64
    init(value: Int64) {
        this.value = value
        require(Character.isValidCodePoint(value), { => "Not a valid code point" })
    }
    let charCount: Int64 = if (value >= Character.MIN_SUPPLEMENTARY_CODE_POINT) {
        2
    } else {
        1
    }
    func toChars(): Array<Rune> {
        return Character.toChars(value)
    }
    func toChars(destination: Array<Rune>, offset: Int64): Int64 {
        return Character.toChars(value, destination, offset)
    }
    func toUnicodeNotation(): String {
        return "U+${value.toString(radix: 16).toAsciiUpper().padStart(4, padding: "0")}"
    }
    public override func toString(): String {
        return toChars().concatToString()
    }
}

extend Int64 {
    func toCodePoint(): CodePoint {
        return CodePoint(this)
    }
}

extend Rune {
    func toCodePoint(): CodePoint {
        return CodePoint(this.code)
    }
}
