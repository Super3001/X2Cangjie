// Regression: top-level `const val X` + `fun X(...)` same-name declaration.
// k2cj's SOC resolve_var_func_collisions only checked Class members (L112-143),
// not top-level Program items. Result: `let X` + `func X` both rendered at
// top level → "redefinition of declaration 'X'".
// Fix: extend SOC to also check Program items for var-func collisions.

const val FOO: String = "foo"

fun FOO(msg: String): String {
    return "${FOO}_${msg}"
}

fun main() {
    println("ok")
}
