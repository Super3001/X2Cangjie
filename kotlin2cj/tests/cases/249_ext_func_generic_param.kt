// Regression: `fun <T> KoinApplication.withConfiguration()` — extension function
// with function-level generic param. parse_fun L703-707 unconditionally appended
// generic_suffix (<T>) to receiver_type, producing `extend KoinApplication<T>`
// even when KoinApplication is non-generic. L710 generic_params.clear() then
// wiped the function's own generic params, so the rendered func had no generics.
// Fix: only append generic_suffix when receiver actually has generic args
// (detected via try_skip_generic_args return value), and don't clear generic_params.

class Container {
    var x: Int = 0
}

fun <T> Container.describe(v: T): String {
    return "container_${x}"
}

fun main() {
    val c = Container()
    c.x = 5
    println(c.describe(42))
}
