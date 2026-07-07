// Regression: `inline fun f(noinline param: () -> T): T`
// Previously parse_param_nodes did not call skip_modifiers (to avoid
// misclassifying `open`/`internal` etc. as parameter-name keywords),
// but this also skipped `noinline`/`crossinline` — which are *only*
// used as inline-fn lambda parameter modifiers and never as param names.
// Result: `noinline` was consumed as the parameter name, then the real
// name `parameters` was seen at the position where `:` was expected.
// Fix: explicitly eat `noinline`/`crossinline` keywords before expect_ident.
//
// Also covers the `<reified T : Any>` parse_generic_params bug: `reified`
// was being pushed as the generic param name itself (replacing T),
// producing `func f<reified>(...): T` and `undeclared type name 'T'`.
// Fix: skip `reified`/`out`/`in` Kotlin generic modifiers in parse_generic_params.

inline fun processItem(noinline producer: () -> Int): Int {
    return producer()
}

inline fun withCrossInline(crossinline block: () -> Int): Int {
    return block()
}

fun main() {
    val x = processItem { 42 }
    val y = withCrossInline { 100 }
    println(x)
    println(y)
}
