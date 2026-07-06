// Regression: generated code containing "Iterator" must NOT trigger
// `import std.iterator.*` — Cangjie 1.0.5 has no std.iterator package
// (Iterator/Iterable live in core and are auto-available).
class CountIterator(val limit: Int) {
    var current = 0

    fun hasNext(): Boolean = current < limit

    fun next(): Int {
        val v = current
        current++
        return v
    }
}

fun main() {
    val result = ArrayList<Int>()
    val iter = CountIterator(5)
    while (iter.hasNext()) {
        result.add(iter.next())
    }
    println(result.joinToString(" "))
}
