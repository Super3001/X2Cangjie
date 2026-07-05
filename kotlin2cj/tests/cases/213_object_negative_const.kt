object Limits {
    private const val missing = -1
    private val delims = charArrayOf(',', ';')
    const val cap = 10

    fun describe(code: Int): String {
        if (code == missing) {
            return "missing"
        }
        return "d" + delims.size.toString() + "c" + cap.toString()
    }
}

fun main() {
    println(Limits.describe(-1))
    println(Limits.describe(5))
}
