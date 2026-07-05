class Lazy<T>(val maker: () -> T) {
    fun value(): T = maker()
}

fun main() {
    val a = Lazy<String?> { null }
    val b = Lazy<Int> { 42 }
    println(a.value() ?: "none")
    println(b.value())
    val x = 3
    val y = 5
    if (x < y) {
        println("lt")
    }
}
