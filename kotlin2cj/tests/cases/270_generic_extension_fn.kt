// Regression (1f R9, cluster generic-extension-fn): Kotlin extension functions with
// FUNCTION-level generic params on a NON-generic bare receiver —
// `inline fun <reified R, reified T1> Module.factoryOf(...)` (koin factoryOf/singleOf
// DSL, R..T22 arities) — were rendered as `extend Module<R,T1>`: the parser
// unconditionally appended the fn generic suffix to the receiver and cleared the
// fn's own generic_params (parse_fun receiver loop). Module is non-generic, so cjc
// exploded with `undeclared type name 'R'/'T1'/...` ×3710 (84% of 1f R9 baseline 4403).
//
// Fix (parser.rs): the generic suffix moves to the receiver ONLY when the receiver
// is written with explicit type args (`fun <T> Box<T>.unwrap()`); a bare receiver
// keeps generic_params on the function itself, rendering as
// `extend Module { func factoryOf<R>(...) }` (generic member fn in extend +
// same-name overloads across arities verified legal by cjc probe).
//
// NOT covered here (pre-existing, untested, R10 candidate): receiver WITH explicit
// type args renders as `extend Box<T>` which cjc rejects — Cangjie generic extension
// needs `extend<T> Box<T>`; mixed fn/receiver generics also mis-append the full fn
// suffix to the receiver. That is the generic-RECEIVER sub-cluster, not this one.
class Registry {
    var count: Int = 0
    fun bump() {
        count = count + 1
    }
}

// bare receiver + fn generics: generics must stay on the function
fun <R> Registry.produce(constructor: () -> R): R {
    bump()
    return constructor()
}

fun <R, T1> Registry.produce(constructor: (T1) -> R, seed: T1): R {
    bump()
    return constructor(seed)
}

fun main() {
    val reg = Registry()
    val a = reg.produce({ 41 })
    val b = reg.produce({ x: Int -> "v" + x }, 7)
    println(a)
    println(b)
    println(reg.count)
}
