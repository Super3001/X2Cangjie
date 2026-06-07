fun count(vararg values: String): Int {
    return values.size
}

fun main() {
    val values = arrayOf("a", "b")
    println(count(*values))
}
