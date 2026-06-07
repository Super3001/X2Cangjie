fun main() {
    val lookupMap = listOf("Amp" to "value")
    var ok = false
    for ((key, value) in lookupMap) {
        val code = key[0].code.toUShort()
        val subSeq = key.subSequence(1, 3)
        ok = code == 'A'.code.toUShort() && subSeq.toString() == "mp" && value == "value"
    }
    println(ok)
}
