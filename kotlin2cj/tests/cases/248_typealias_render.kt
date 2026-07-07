// Regression: typealias rendered as comment `// typealias X = Y` (render.rs L457)
// but type references use short name X. Cangjie can't find X without `type X = Y`
// declaration. Fix: render as Cangjie `type X = Y` syntax.

typealias IntPair = Pair<Int, Int>

fun sum(p: IntPair): Int {
    return p.first + p.second
}

fun main() {
    println("ok")
}
