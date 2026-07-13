// Regression (1f R11, cluster trailing-lambda-default): Kotlin middle-default
// parameters that collide with trailing-lambda call sites —
// `inline fun <R> Module.factoryOf(constructor: () -> R, options: Options<R>? = null)`
// — were rendered with the middle default DOWNGRADED to a positional parameter
// (render.rs:1378-1395 + fn_params:3374-3378, R2 cluster middle-default-param).
// The downgrade drops `!` and `= None`, so cjc sees the function as taking two
// required positional parameters. A trailing-lambda call `factoryOf { lambda }`
// (parser: trailing lambda becomes args[0]) then has args.len()=1 < params.len()=2,
// and cjc reports `missing argument for parameter list '(Option<Qualifier>, ...)'`.
//
// In 1f R10 baseline this was 107 errors / 543 total (20%), all koin DSL
// factoryOf/singleOf/scopedOf calls (R..T22 arities × 3 DSLs).
//
// Fix (render.rs render_call_args_with_params + fn_params):
// 1. fn_params returns (name, ty, has_default_degraded, has_default_original) so the
//    call site knows which params HAD a default in Kotlin source (vs degraded now).
// 2. When args.len() < params.len() and the omitted PREFIX params all had defaults in
//    Kotlin source, prepend `Option.None` (positional, since definition downgraded)
//    — or `name: None` (named, when definition kept the `!`) — and align args to the
//    tail. This restores the trailing-lambda semantics under downgrade.
//
// NOT covered here (R12+ candidates): non-?T default values (`Bool = false`, `Int = 0`)
// are not auto-filled; `single(qualifier = null, createdAtStart = false, def)` still
// reports missing. `appDeclaration()` function-typed variable call needs `.invoke()`.

class Box {
    var touched: Bool = false
}

// middle-default param + trailing lambda: `def` is the last param, `opts` is middle.
// Position call `decorate(b) { x -> x }` must become `decorate(b, Option.None, { x -> x })`.
class DecorOptions

fun <R> decorate(box: Box, opts: DecorOptions? = null, def: (Int) -> R): R {
    box.touched = true
    return def(0)
}

// Class-member flavor (mirrors Module.single/factory): downgrade applies, call site
// still must align trailing lambda to the tail.
class Container {
    fun <R> make(qual: String? = null, def: () -> R): R {
        return def()
    }
}

fun main() {
    val b = Box()
    val r1 = decorate<Int>(b) { x: Int -> x + 100 }
    println(r1)
    println(b.touched)

    val c = Container()
    val r2 = c.make { "hi" }
    println(r2)
}
