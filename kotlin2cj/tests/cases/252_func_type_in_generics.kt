// Regression (2a R4): function type inside generic args. `List<Pair<(Int)->Boolean,
// String>>` — the `>` in the `->` arrow corrupted split_top's bracket-depth tracking,
// mangling the type to `ArrayList<((T) -), ...>>`. Fix: split_top treats `->` as a unit.
class Registry {
    val handlers: List<Pair<(Int) -> Boolean, String>> = listOf(
        Pair({ n: Int -> n > 0 }, "positive"),
        Pair({ n: Int -> n < 0 }, "negative")
    )
    fun classify(x: Int): String {
        for ((pred, label) in handlers) {
            if (pred(x)) {
                return label
            }
        }
        return "zero"
    }
}

fun main() {
    val r = Registry()
    println(r.classify(5))
    println(r.classify(-3))
    println(r.classify(0))
}
