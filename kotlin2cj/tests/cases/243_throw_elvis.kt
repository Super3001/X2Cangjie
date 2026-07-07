// Regression: `x ?: throw IllegalArgumentException("...")` — Kotlin Elvis with
// throw expression as rhs. k2cj's 1e R2 fix handled `= throw X(...)` function
// expression body (parse_stmt L1342), but NOT throw as a sub-expression. Elvis
// rhs goes through parse_to → parse_range → parse_unary → parse_primary, none
// of which recognized `throw` — so the throw keyword was rendered bare without
// its exception argument, producing `?? throw` (cjc: "expected expression
// after keyword 'throw', found '}'").
// Fix: handle `throw` at expression level in parse_unary.

fun findOrNull(x: Int?): Int {
    return x ?: throw IllegalArgumentException("null")
}

fun main() {
    println("ok")
}
