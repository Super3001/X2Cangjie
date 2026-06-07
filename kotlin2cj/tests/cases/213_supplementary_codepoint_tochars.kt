class CharsUtils {
    companion object {
        fun toChars(codePoint: Int): CharArray {
            return charArrayOf(codePoint.toChar())
        }
    }
}

fun main() {
    val builder = StringBuilder()
    for (it in CharsUtils.toChars(0x1F600)) {
        builder.append(it)
    }
    println(builder.toString())
}
