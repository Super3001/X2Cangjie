package ksoup_cj

import std.convert.*

class Character {
    private init() {
        this.MIN_SUPPLEMENTARY_CODE_POINT = 0x010000
        this.MIN_HIGH_SURROGATE = 0xD800
        this.MIN_LOW_SURROGATE = 0xDC00
        this.MAX_LOW_SURROGATE = 0xDFFF
        this.MIN_SURROGATE = MIN_HIGH_SURROGATE
        this.MAX_SURROGATE = MAX_LOW_SURROGATE
        this.MAX_CODE_POINT = 0X10FFFF
    }
    public static let INSTANCE = Character()
    let MIN_SUPPLEMENTARY_CODE_POINT: Int64
    let MIN_HIGH_SURROGATE: Rune
    let MIN_LOW_SURROGATE: Rune
    let MAX_LOW_SURROGATE: Rune
    let MIN_SURROGATE: Rune
    let MAX_SURROGATE: Rune
    let MAX_CODE_POINT: Int64
    static func toCodePoint(high: Rune, low: Rune): Int64 {
        return ((Int64(UInt32(high)) << 10) + Int64(UInt32(low))) + ((Character.INSTANCE.MIN_SUPPLEMENTARY_CODE_POINT - (Int64(UInt32(Character.INSTANCE.MIN_HIGH_SURROGATE)) << 10)) - Int64(UInt32(Character.INSTANCE.MIN_LOW_SURROGATE)))
    }
    static func isDigit(codePoint: CodePoint): Bool {
        return Rune(UInt32(codePoint.value)).isAsciiNumber()
    }
    static func isDigit(codePointValue: Int64): Bool {
        return Rune(UInt32(codePointValue)).isAsciiNumber()
    }
    static func isValidCodePoint(codePoint: Int64): Bool {
        let plane = codePoint >> 16
        return plane < ((Character.INSTANCE.MAX_CODE_POINT + 1) >> 16)
    }
    static func isBmpCodePoint(codePoint: Int64): Bool {
        return (codePoint >> 16) == 0
    }
    static func highSurrogate(codePoint: Int64): Rune {
        return Rune(UInt32(((codePoint >> 10) + (Int64(UInt32(Character.INSTANCE.MIN_HIGH_SURROGATE)) - (Character.INSTANCE.MIN_SUPPLEMENTARY_CODE_POINT >> 10)))))
    }
    static func lowSurrogate(codePoint: Int64): Rune {
        return Rune(UInt32(((codePoint & 0x3ff) + Int64(UInt32(Character.INSTANCE.MIN_LOW_SURROGATE)))))
    }
    static func toSurrogates(codePoint: Int64, dst: Array<Rune>, index: Int64) {
        dst[index + 1] = lowSurrogate(codePoint)
        dst[index] = highSurrogate(codePoint)
    }
    static func toChars(codePoint: Int64): Array<Rune> {
        return if (isBmpCodePoint(codePoint)) {
            [Rune(UInt32(codePoint))]
        } else if (isValidCodePoint(codePoint)) {
            let result = Array<Rune>(2, { _ => r'\u{0000}' })
            toSurrogates(codePoint, result, 0)
            result
        } else {
            throw IllegalArgumentException("Not a valid Unicode code point: 0x${codePoint.toString(radix: 16).toAsciiUpper()}")
        }
    }
    static func toChars(codePoint: Int64, dst: Array<Rune>, dstIndex: Int64): Int64 {
        return if (isBmpCodePoint(codePoint)) {
            dst[dstIndex] = Rune(UInt32(codePoint))
            1
        } else if (isValidCodePoint(codePoint)) {
            toSurrogates(codePoint, dst, dstIndex)
            2
        } else {
            throw IllegalArgumentException("Not a valid Unicode code point: 0x${codePoint.toString(radix: 16).toAsciiUpper()}")
        }
    }
}

extend String {
    func codePointValueAt(index: Int64): Int64 {
        if (!(indices.contains(index))) {
            throw IndexOutOfBoundsException()
        }
        let firstChar = this[index]
        if (firstChar.isHighSurrogate() && ((index + 1) < length)) {
            let nextChar = this[index + 1]
            if (nextChar.isLowSurrogate()) {
                return Character.toCodePoint(firstChar, nextChar)
            }
        }
        return firstChar.code
    }
}

extend String {
    func codePointAt(index: Int64): CodePoint {
        return this.codePointValueAt(index).toCodePoint()
    }
}
    // NOTE: inline reified function omitted — not supported by translator