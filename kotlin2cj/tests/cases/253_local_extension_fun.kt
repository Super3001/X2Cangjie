// Regression (2a R4): local extension function declared inside a function body
// (`fun Recv.helper(){...}` inside `fun Recv.runTwice()`) — Kotlin-legal but Cangjie
// forbids nested `extend`. Rendered as an invalid nested `extend` block. Fix: render
// local extension funcs as plain nested funcs (receiver members resolve via outer this).
class Counter {
    var total: Int = 0
    fun bump() {
        total += 1
    }
}

fun Counter.runTwice() {
    fun Counter.helper() {
        bump()
        bump()
    }
    helper()
}

fun main() {
    val c = Counter()
    c.runTwice()
    println(c.total)
}
