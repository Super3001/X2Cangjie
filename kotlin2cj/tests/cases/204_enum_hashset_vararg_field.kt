class Decoder(vararg options: Option) {
    enum class Option {
        Required,
        Optional
    }

    private val selected: Set<Option> =
        if (options.isEmpty()) setOf(Option.Required) else setOf(*options)

    fun has(option: Option): Boolean {
        return selected.contains(option)
    }
}

fun main() {
    val decoder = Decoder(Decoder.Option.Optional)
    println("${decoder.has(Decoder.Option.Optional)}:${decoder.has(Decoder.Option.Required)}")
}
