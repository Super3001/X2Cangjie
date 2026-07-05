open class Shape {
    open fun area(): Int = 0
}

class Square(val side: Int) : Shape() {
    override fun area(): Int = side * side
}

fun <T : Shape> describe(s: T, label: String): String {
    return label + ":" + s.area().toString()
}

fun <T : Comparable<T>> larger(a: T, b: T): T {
    return if (a > b) a else b
}

fun main() {
    val sq = Square(4)
    println(describe(sq, "square"))
    println(larger(3, 9))
    println(larger("apple", "pear"))
}
