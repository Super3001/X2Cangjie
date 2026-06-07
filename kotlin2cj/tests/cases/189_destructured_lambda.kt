fun main() {
    val values = listOf("left" to "right", "up" to "down")
    val swapped = values.map { (a, b) -> b to a }
    for ((a, b) in swapped) {
        println("$a:$b")
    }
}
