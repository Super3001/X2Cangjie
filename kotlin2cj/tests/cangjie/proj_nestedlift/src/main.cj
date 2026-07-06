package proj_nestedlift

main() {
    let n = Comment("hello")
    println(n.show())
    let tc = TokenComment()
    tc.data = "world"
    println(tc.show())
    let d: Doctype = Doctype()
    d.name = "html"
    println(d.name)
}
