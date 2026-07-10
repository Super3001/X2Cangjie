// Regression (1g R19, cluster not-member-of-class): Kotlin/Java
// `StringBuilder.appendCodePoint(Int)` — appends the char for a Unicode code point.
// ksoup uses it in Tokeniser/TokenData/TokenQueue/StringUtil (×6 errors:
// "'appendCodePoint' is not a member of class 'StringBuilder'").
//
// Cangjie StringBuilder has append(Rune) but NO appendCodePoint (core std: append
// overloads + reset + toString only). Fix (render_calls.rs): map
// `sb.appendCodePoint(cp)` → `sb.append(Rune(UInt32(cp)))`. No looks_string_builder
// gate (that predicate misses field / nullable-unwrapped receivers), since
// appendCodePoint is StringBuilder-exclusive.
fun build(): String {
    val sb = StringBuilder()
    sb.appendCodePoint(72)    // 'H'
    sb.appendCodePoint(105)   // 'i'
    sb.appendCodePoint(0x1F600) // emoji code point (multi-byte)
    return sb.toString()
}

// Nullable receiver (mirrors ksoup TokenData `builder?.appendCodePoint`): the receiver
// is unwrapped by render_call_recv before the appendCodePoint mapping applies.
fun buildNullable(): String {
    val sb: StringBuilder? = StringBuilder()
    sb!!.appendCodePoint(65) // 'A'
    return sb.toString()
}

fun main() {
    println(build())          // Hi😀
    println(buildNullable())  // A
}
