// Regression for 1f R10 (koin-core): three generic typealiases were silently
// dropped (rendered as `// typealias X<T> = ...`) because:
//   (a) render.rs `Kind::TypeAlias` had `name.contains('<')` gate that always
//       commented out generic aliases, and
//   (b) parser.rs `parse_type_raw` recognized `ReceiverType.()` only when the
//       receiver had no generic args — `BeanDefinition<T>.() -> Unit` was
//       truncated to `BeanDefinition<T>`, dropping the function-type part.
//
// Both are fixed in R10. This test covers all three koin forms:
//   1. `typealias Definition<T> = Scope.(ParametersHolder) -> T`
//   2. `typealias OnCloseCallback<T> = (T?) -> Unit`
//   3. `typealias DefinitionOptions<T> = BeanDefinition<T>.() -> Unit`
// + a non-receiver generic typealias for breadth.

class Scope
class ParametersHolder
class BeanDefinition<T>

typealias Definition<T> = Scope.(ParametersHolder) -> T
typealias OnCloseCallback<T> = (T?) -> Unit
typealias DefinitionOptions<T> = BeanDefinition<T>.() -> Unit
typealias StringList<T> = ArrayList<T>

fun makeDef(): Definition<Int> = { p, _ -> 42 }
fun makeClose(): OnCloseCallback<Int> = { x -> }
fun makeOpts(): DefinitionOptions<String> = { b -> }

fun main() {
    val d = makeDef()
    val r = d(Scope(), ParametersHolder())
    val c = makeClose()
    val o = makeOpts()
    o(BeanDefinition())
    val sl: StringList<String> = arrayListOf("a", "b")
    println("ok r=$r sl=${sl.size}")
}
