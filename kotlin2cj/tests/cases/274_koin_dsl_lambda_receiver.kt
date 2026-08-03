// Regression (1f R13, cluster koin-dsl-lambda-receiver): koin DSL
// `factory { new(constructor) }` / `single(...) { new(constructor) }` /
// `scoped { new(constructor) }` calls an inline reified `Scope.new(constructor)`
// extension member function from inside a trailing lambda whose Kotlin
// signature is `Scope.(ParametersHolder) -> R` (lambda-with-receiver).
//
// k2cj rendered the lambda as `{ => new(constructor) }` (no params bound),
// losing the receiver context — `new(constructor)` looked up `new` as a free
// function (none exists; it's an `extend Scope` member) → cjc reports
// "undeclared identifier 'new'" (1f R12 baseline: 92 errors across
// factoryOf/singleOf/scopedOf/scopedFactoryOf × 22 arities × 4 files).
//
// Fix (parser.rs try_restructure_koin_dsl_lambda): detect the koin DSL
// pattern (callee is `factory`/`single`/`scoped` + trailing lambda whose
// body is a single `new(constructor)` call), restructure the lambda:
//   - add synthetic params `["scope", "params"]`
//   - rewrite the body's `new` NameRef to `Member(scope, "new")`
// so the rendered lambda is `{ scope, params => scope.new(constructor) }`.
//
// NOT covered here (R14+ candidates): `get()` inside `Scope.new`'s body
// still fails to infer `<T1>` (reified T type literal, high-risk cluster).

class Scope

class ParametersHolder

class Module {
    fun factory(qualifier: String?, def: (Scope, ParametersHolder) -> Int): Int {
        return def(Scope(), ParametersHolder())
    }
    fun single(qualifier: String?, createdAtStart: Boolean, def: (Scope, ParametersHolder) -> Int): Int {
        return def(Scope(), ParametersHolder())
    }
    fun scoped(qualifier: String?, def: (Scope, ParametersHolder) -> Int): Int {
        return def(Scope(), ParametersHolder())
    }
}

// Non-generic version of Scope.new (matches koin's arity-0 `inline fun <reified R> Scope.new(constructor: () -> R): R = constructor()`)
fun Scope.new(constructor: () -> Int): Int {
    return constructor()
}

fun Module.factoryOf(constructor: () -> Int): Int {
    return factory(null, { new(constructor) })
}

fun Module.singleOf(constructor: () -> Int): Int {
    return single(null, false, { new(constructor) })
}

fun Module.scopedOf(constructor: () -> Int): Int {
    return scoped(null, { new(constructor) })
}

fun main() {
    val m = Module()
    val r1 = m.factoryOf({ 42 })
    println(r1)
    val r2 = m.singleOf({ 99 })
    println(r2)
    val r3 = m.scopedOf({ 7 })
    println(r3)
}
