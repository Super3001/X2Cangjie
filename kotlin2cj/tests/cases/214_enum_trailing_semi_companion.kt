enum class Charset {
    ascii,
    utf,
    fallback,
    ;

    companion object {
        fun tag(): String = "cs"
    }
}

fun main() {
    val c = Charset.utf
    println(c)
    println(Charset.fallback)
}
