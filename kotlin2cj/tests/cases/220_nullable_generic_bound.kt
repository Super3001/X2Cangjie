open class Item(val id: Int)

fun <E : Item?> countOf(list: List<E>): Int {
    return list.size
}

fun <E : Item?> firstId(list: List<E>, fallback: Int): Int {
    if (list.isEmpty()) {
        return fallback
    }
    return fallback + list.size
}

fun main() {
    val xs = listOf(Item(1), Item(2))
    println(countOf(xs))
    println(firstId(xs, 10))
}
