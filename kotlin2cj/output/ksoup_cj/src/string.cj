package ksoup_cj

extend String.Companion {
    func buildString(charArray: Array<Rune>, offset: Int64, length: Int64): String {
        return charArray.concatToString(offset, offset + length)
    }
}
