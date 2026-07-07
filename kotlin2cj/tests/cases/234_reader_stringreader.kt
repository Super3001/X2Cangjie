// Stub regression: `Reader` / `StringReader` minimal stubs (java.io style).
fun main() {
    val r = StringReader("abc")
    println(r.read())
    println(r.read())
    println(r.read())
    println(r.read())
}
