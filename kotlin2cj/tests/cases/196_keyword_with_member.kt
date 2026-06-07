class Wrapper {
    fun with(value: String): String {
        return value
    }
}

fun main() {
    val wrapper = Wrapper()
    println(wrapper.with("ok"))
}
