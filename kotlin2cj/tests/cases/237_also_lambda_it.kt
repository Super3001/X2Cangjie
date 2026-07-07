// Regression: `also` lambda inlines as IIFE with `let _also_it = recv`.
// Previously generated `let it = _also_it` alias decl clashed with an
// outer-scope `it` (another lambda's default param). Now the body's `it`
// NameRefs are rewritten to `_also_it` directly, no alias decl.
fun main() {
    val x = 5
    val y = x.also { it ->
        println(it)
    }
    println(y)
}
