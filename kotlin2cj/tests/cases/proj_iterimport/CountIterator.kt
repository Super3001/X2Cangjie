// Regression: project mode must NOT inject `import std.iterator.*` for code
// containing "Iterator" — Cangjie 1.0.5 has no std.iterator package.
class CountIterator(val limit: Int) {
    var current = 0

    fun hasNext(): Boolean = current < limit

    fun next(): Int {
        val v = current
        current++
        return v
    }
}
