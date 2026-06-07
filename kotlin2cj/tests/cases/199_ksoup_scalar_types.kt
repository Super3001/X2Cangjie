fun main() {
    val seen: MutableSet<UShort> = mutableSetOf()
    seen.add('A'.code.toUShort())
    val chars = CharArray(2)
    chars[0] = 'o'
    chars[1] = 'k'
    val r: IntRange = 1..3
    println("${seen.contains('A'.code.toUShort())}:${r.contains(2)}:${chars[0]}${chars[1]}")
}
