// Regression: `fun KClass<*>.saveCache()` — Kotlin star-projection in extension
// function receiver type. k2cj's parse_fun L697 misjudged `<*>` as the function's
// own generic params (because generic_params was empty + is_sym("<") true),
// then parse_generic_params pushed `*` to gen_tokens without mapping to `Any`.
// Result: `extend KClass<*>` rendered with literal `*`, cjc rejected with
// "expected type name after '<', found '*'".
// Fix: in parse_generic_params Sym branch, map `*` to `Any` (star-projection).

class Box<T>

fun Box<*>.describe(): String {
    return "box"
}

fun main() {
    println("ok")
}
