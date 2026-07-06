fun main() {
    val n = Comment("hello")
    println(n.show())
    val tc = Token.Comment()
    tc.data = "world"
    println(tc.show())
    val d: Token.Doctype = Token.Doctype()
    d.name = "html"
    println(d.name)
}
