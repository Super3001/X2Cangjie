// Regression (2a R3, cluster A): class/interface-level generic variance
// modifiers `in`/`out` were captured as the parameter NAME (dropping the real
// name), rendering `class Box<out>` / `interface Predicate<in>` — invalid.
// parse_class now skips `in`/`out`/`reified` before taking the real name,
// mirroring the function-level parse_generic_params (1f R1). Expect T/K/V, A/B.
class Box<out T>(val value: T) {
    fun get(): T {
        return value
    }
}

class Sink<in T> {
    fun consume(value: T): Int {
        return 1
    }
}

class Bridge<in A, out B>(val output: B) {
    fun accept(input: A): B {
        return output
    }
}

fun main() {
    val b = Box<Int>(7)
    println(b.get())
    val s = Sink<String>()
    println(s.consume("hi"))
    val br = Bridge<String, Int>(99)
    println(br.accept("x"))
}
