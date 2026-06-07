open class Translator {
    fun with(vararg translators: Translator): Int {
        val newArray = arrayOf(this, *translators)
        return newArray.size
    }
}

fun main() {
    val first = Translator()
    val others = arrayOf(Translator(), Translator())
    println(first.with(*others))
}
