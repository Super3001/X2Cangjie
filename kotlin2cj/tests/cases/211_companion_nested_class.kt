class Registry {
    companion object {
        val seed: Int = 3

        class Entry(val key: String, val weight: Int) {
            fun score(): Int = weight * 2
        }
    }

    fun lookup(key: String): Int {
        return Entry(key, 10).score() + seed
    }
}

fun main() {
    val r = Registry()
    println(r.lookup("a"))
    println(Registry.seed)
}
