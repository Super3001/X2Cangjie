fun main() {
    val lookupMap = listOf("𝔄mp" to "hit")
    val prefixSet: MutableSet<UShort> = mutableSetOf()
    var matched = false
    for ((key, value) in lookupMap) {
        prefixSet.add(key[0].code.toUShort())
        if (prefixSet.contains("𝔄mp"[0].code.toUShort())) {
            val subSeq = key.subSequence(0, key.length)
            matched = subSeq.toString() == "𝔄mp" && value == "hit"
        }
    }
    println(matched)
}
