// Regression: CtorParam `var mode` collides with method `fun mode(...)`.
// SOC renames the CtorParam field to `_mode` (member decl + NameRef cascade).
// Note: setter body `this.X = X` is a separate cluster (member-access render,
// not NameRef) — not covered here.
class Builder(var mode: Int) {
    fun getMode(): Int {
        return mode
    }
}

fun main() {
    val b = Builder(1)
    println(b.getMode())
}
