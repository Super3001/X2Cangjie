object Maps {
    val base = listOf("a" to "b")
    val inverted = invert(base)

    private fun invert(list: List<Pair<String, String>>): List<Pair<String, String>> {
        val result = mutableListOf<Pair<String, String>>()
        for ((left, right) in list) {
            result.add(right to left)
        }
        return result
    }
}

fun main() {
    println(Maps.inverted[0].first)
}
