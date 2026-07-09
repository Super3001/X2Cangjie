// Regression (1g R10): over-unwrap. `if (x != null) { ... x!! ... }` renders the null
// check as a smart-cast rebind `if (let Some(xValue) <- x) { let x = xValue; ... }`, so
// inside the block `x` is already the non-Option local. The `x!!` ForceUnwrap must NOT
// emit `.getOrThrow()` there (that produced "'getOrThrow' is not a member of class X").
// Boundary: an unguarded `!!` (no enclosing null-check) MUST still unwrap.
class Box(val label: String) {
    fun name(): String = label
}

class Holder {
    var inner: Box? = null

    // Pattern under fix: null-check guard on a field + `!!` inside the guarded block.
    fun describe(): String {
        if (inner != null) {
            return inner!!.name()
        }
        return "empty"
    }

    // else-branch of `== null` guard is also the non-null region for the rebind.
    fun describeEq(): String {
        if (inner == null) {
            return "none"
        }
        return inner!!.name()
    }
}

// Boundary: `!!` with no enclosing null-check must still unwrap (getOrThrow).
fun unwrapNoGuard(b: Box?): String {
    return b!!.name()
}

fun main() {
    val h = Holder()
    println(h.describe())        // empty
    println(h.describeEq())      // none
    h.inner = Box("hello")
    println(h.describe())        // hello
    println(h.describeEq())      // hello
    println(unwrapNoGuard(Box("world")))  // world
}
