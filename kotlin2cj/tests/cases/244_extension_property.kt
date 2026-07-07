// Regression: `val ReceiverType.name: T get() = expr` — Kotlin extension property.
// k2cj's parse_var_decl read "Duration" as the variable name, then expected `:`
// or `=` but got `.` (receiver separator). Result: only "Duration" rendered,
// rest skipped. Fix: detect `.` after first ident, treat as extension property,
// convert to extension function (Func Kind with receiver_type) reusing existing
// extend-render path.

class MyType {
    var x: Int = 0
}

val MyType.value: Int get() = 42

fun main() {
    println("ok")
}
