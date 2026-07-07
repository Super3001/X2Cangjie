// Regression: `fun f(block: ReceiverType.() -> R)` — Kotlin receiver-function-type
// parameter. k2cj's parse_type_raw didn't recognize `Type.()` syntax, so after
// parsing `ReceiverType` as a type it expected `)` but got `.` (the receiver
// separator). Fix: detect `Ident.<optional generic args>.()` pattern in
// parse_type_raw — consume the `.` and prepend ReceiverType to the function
// type's parameter list (Cangjie `(ReceiverType) -> R` is the closest match).

class Builder {
    var x: Int = 0
}

fun configure(block: Builder.() -> Unit): Builder {
    return Builder()
}

fun useBuilder(block: Builder.() -> Int): Int {
    return 0
}

fun main() {
    println("ok")
}
