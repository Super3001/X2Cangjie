class Box internal constructor(
    private val value: String
) {
    fun get(): String {
        return value
    }
}

fun main() {
    println(Box("ok").get())
}
