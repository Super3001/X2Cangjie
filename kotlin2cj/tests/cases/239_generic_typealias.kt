// Regression: `typealias Name<T> = TargetType<T>` triggered PARSE ERROR
// "期望 '=', 但得到 Sym('<')" — parse_typealias read the name then
// expected `=` immediately, but the next token was `<` from the generic
// parameter list. Fix: after reading the name, if the next token is `<`,
// call parse_generic_params to consume the generic parameter list before
// expecting `=`.

typealias StringList = List<String>
typealias StringMap<V> = Map<String, V>
typealias IntToString = (Int) -> String

fun main() {
    println("ok")
}
