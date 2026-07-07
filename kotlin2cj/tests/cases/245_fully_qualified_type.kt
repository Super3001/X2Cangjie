// Regression: `org.koin.dsl.KoinAppDeclaration` — Kotlin fully-qualified type
// reference. k2cj's parse_type_raw L2867 `while is_sym(".") && peek_next_is_ident`
// concatenated all parts into `a.b.c.Type`, rendering the package prefix as
// literal `.`-separated idents. Cangjie resolves types via import, not package
// prefix; nested classes are already renamed by apply_nested_lifting (1g R1).
// Fix: only keep the last ident segment in the `.` loop.

class Foo {
    override fun toString(): String {
        return "foo"
    }
}

fun makeFoo(): Foo {
    return Foo()
}

fun main() {
    val f = makeFoo()
    println(f)
}
