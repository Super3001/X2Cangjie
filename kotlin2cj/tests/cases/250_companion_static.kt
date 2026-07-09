// Regression (2a R3, cluster B guard): companion-object members are lifted to
// `static` funcs. The cluster-B fix strips `override` when statifying (static +
// override conflict) and strips top-level `override` in render_func. This test
// guards the common companion-static factory path still renders + runs after
// those edits. (The override-strip's clearing of the `static override` conflict
// on `object : Interface` singletons is verified by the 2a re-translation.)
class Calculator {
    companion object {
        fun add(a: Int, b: Int): Int {
            return a + b
        }

        fun zero(): Int {
            return 0
        }
    }

    fun mul(a: Int, b: Int): Int {
        return a * b
    }
}

fun main() {
    println(Calculator.add(3, 4))
    println(Calculator.zero())
    println(Calculator().mul(5, 6))
}
