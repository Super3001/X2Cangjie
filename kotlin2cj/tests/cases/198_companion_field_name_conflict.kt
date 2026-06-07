class Encoder private constructor(val range: IntRange, val between: Boolean) {
    fun allows(value: Int): Boolean {
        return between == range.contains(value)
    }

    companion object {
        fun between(low: Int, high: Int): Encoder {
            return Encoder(low..high, true)
        }
    }
}

fun main() {
    val encoder = Encoder.between(2, 4)
    println(encoder.allows(3))
}
