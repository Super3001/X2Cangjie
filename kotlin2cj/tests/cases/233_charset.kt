// Stub regression: `Charset` / `Charsets` / `CharsetEncoder` minimal stubs.
fun main() {
    val cs = Charsets.UTF_8
    println(cs.name())
    val enc = cs.newEncoder()
    println(enc.canEncode('A'))
    println(enc.charset() == cs)
}
