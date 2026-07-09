class Door : AutoCloseable {
    var isOpen = true

    override fun close() {
        isOpen = false
    }
}

fun main() {
    val d = Door()
    d.close()
    println(d.isOpen)
}
