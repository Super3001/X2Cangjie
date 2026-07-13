// Regression (1f R12, cluster trailing-lambda-default, non-?T defaults):
// R11 fix covered `?T = null` middle-default params (補 `Option.None` /
// `name: None`). But koin `single(qualifier: Qualifier? = null,
// createdAtStart: Boolean = false, definition: Definition<T>)` has a
// NON-NULLABLE middle default (`Bool = false`). R11 returned None when
// middle params were not `?T` (conservative), so `single { lambda }` calls
// still missed the `createdAtStart` slot and cjc reported
// `missing argument for parameter list '(Option<Qualifier>, Bool, ...)'`.
// That was 23 errors / 619 in 1f R11 baseline.
//
// Fix (R12): fn_params returns a 5-tuple adding `default_value_str` — the
// rendered Kotlin-side default value string (`null`→`None`, `false`→`false`,
// `0`→`0`, etc.). render_call_args_with_params fills the middle skipped
// slots with the rendered default string directly (positional when
// definition downgraded, named with `name: value` when not).
//
// NOT covered here (R13+ candidates): function-typed variable call
// `appDeclaration()` needs `.invoke()`; peek_is_generic_ctor misclassifies
// `c.make<String>` (receiver + method + generic args) as `<` comparison.

class Counter {
    var started: Int = 0
    var eager: Boolean = false
}

// Middle default with Bool (mirrors koin Module.single's `createdAtStart: Boolean = false`)
fun <R> single(c: Counter, qualifier: String? = null, createdAtStart: Boolean = false, def: () -> R): R {
    if (createdAtStart) {
        c.started = c.started + 1
    }
    c.eager = createdAtStart
    return def()
}

// Middle default with Int (mirrors `limit: Int = 0` style)
fun <R> withLimit(c: Counter, seed: Int = 0, def: (Int) -> R): R {
    return def(seed)
}

fun main() {
    val c = Counter()
    val r1 = single<Int>(c) { 42 }
    println(r1)
    println(c.eager)        // false (default)
    println(c.started)      // 0 (default not started)

    val r2 = withLimit<String>(c) { x: Int -> "n=" + x.toString() }
    println(r2)             // n=0 (default seed)

    // Explicit non-default values still work
    val r3 = single<Int>(c, null, true, { 99 })
    println(r3)
    println(c.eager)        // true (explicit)
    println(c.started)      // 1 (started)
}
