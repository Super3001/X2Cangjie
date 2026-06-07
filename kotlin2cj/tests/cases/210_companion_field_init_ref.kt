class Decoder(vararg options: String) {
    val selected: Set<String> = if (options.isEmpty()) DEFAULT_OPTIONS else setOf(*options)

    companion object {
        val DEFAULT_OPTIONS = setOf("semi")
    }
}

fun main() {
    println(Decoder().selected.contains("semi"))
}
