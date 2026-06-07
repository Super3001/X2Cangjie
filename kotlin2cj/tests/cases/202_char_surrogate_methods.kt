fun main() {
    val high = Char.MIN_HIGH_SURROGATE
    val low = Char.MIN_LOW_SURROGATE
    println("${high.isHighSurrogate()}:${low.isLowSurrogate()}")
}
