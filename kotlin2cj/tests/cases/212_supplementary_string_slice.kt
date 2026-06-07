fun main() {
    val s = "𝔄mp"
    println("${s.length}:${s.subSequence(0, s.length)}:${s.substring(1)}:${s.take(2)}:${s.drop(1)}")
}
