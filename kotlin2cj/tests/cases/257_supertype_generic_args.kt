// Regression (2a R6 cluster1): supertype generic args dropped in the interface/parent
// position. `class X : Container<Int>` / `interface Labeled<T> : Container<T>` rendered
// as raw `<: Container` -> cjc 'generic type should be used with type argument'. Only the
// superclass branch (with `(...)`) kept type_args; the interface branch dropped them. Fix:
// apply captured type_args in the interface branch too.
interface Container<T> {
    fun get(): T
}

interface Labeled<T> : Container<T> {
    fun label(): String
}

class IntBox : Labeled<Int> {
    override fun get(): Int {
        return 42
    }
    override fun label(): String {
        return "int"
    }
}

fun main() {
    val b: Labeled<Int> = IntBox()
    println(b.get())
    println(b.label())
}
