class Collector() {
    private val items = mutableListOf<String>()

    constructor(vararg values: String) : this() {
        items.addAll(values)
    }

    fun size(): Int {
        return items.size
    }
}

fun main() {
    val c = Collector("a", "b")
    println(c.size())
}
